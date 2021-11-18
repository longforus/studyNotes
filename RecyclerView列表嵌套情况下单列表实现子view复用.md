# RecyclerView列表嵌套情况下单列表实现子view复用

标签（空格分隔）： Android

---
## 情况
开发中有时候会遇到这样的情况:外部是一个RecyclerView,每个item的内部还存在着另外一个列表,这种情况下的解决方法,我想到2种.
1. 是使用列表嵌套,在外层RecyclerView的item中再加入一个RecyclerView.这样做的话存在滑动冲突的可能,而且需要另外创建内部列表的adapter和viewHolder.
2. 是只使用一个RecyclerView,在item的列表位置加入一个容器LinearLayout,inflate每个内部item add到容器中,这样做的话又存在过多的内部item inflate的问题,因为在外部item复用的时候每次都会inflate内部列表item个数的内部item view,毫无疑问这肯定是很耗时的.可能是高速滑动下造成卡顿.

## 思考

试想在item内部使用RecyclerView的话也是为了内部item view的复用,但是在不同的外部item间,内部的item是否得到了复用呢?每个外部item的内部都有一个内部item的adapter,他们是互相隔离的,不能互相复用内部item的view,在内部list不能撑满整个屏幕的情况下,未必能实现内部item的复用.(猜想未测试)

那么要是使用方法2,自行实现内部Item的复用是否可行呢?笔者进行了初步测试是可行的.构思如下:
1. 每个内部list至少存在一个item,这个item对应的view是可以直接复用的.
2. 设当前外部item的内部list size = 2,复用的外部hodler的前一个item的内部list size = 4,那么在这个holder的容器中就冗余了2个内部item,把他从parent中移除,并保存到另外的队列q中.
3. 设当前外部item的内部list size = 4,复用的外部hodler的前一个item的内部list size = 2,那么在这个holder的容器就还需要2个内部item,如果当前队列q不空,就poll一个内部item view出来添加到容器中,如果空则inflate一个新的内部item view 使用.

如果这样的话,队列q中可能存在的最大item数量不会操作最大内部item list的数量.因为使用集合装view是很耗费内存的,所以内存占用还待测试.
## demo
以上想法初步实现如下:
### adapter
```java
public abstract class CacheSubRvAdapter<T> extends BaseRecyclerViewAdapter<T> {
    protected Queue<View> subViewQueue;
    public CacheSubRvAdapter(Activity context) {
        super(context);
        subViewQueue = new LinkedList<>();
    }

    public CacheSubRvAdapter(Context context) {
        super(context);
        subViewQueue = new LinkedList<>();
    }

    public CacheSubRvAdapter(Activity context, List<T> list) {
        super(context, list);
        subViewQueue = new LinkedList<>();
    }

    public CacheSubRvAdapter(Context context, List<T> list) {
        super(context, list);
        subViewQueue = new LinkedList<>();
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        RecyclerView.ViewHolder viewHolder = super.onCreateViewHolder(parent, viewType);
        if (viewHolder instanceof CacheSubHolder) {
            ((CacheSubHolder) viewHolder).setSubViewQueue(subViewQueue);
        }
        return viewHolder;
    }

    @Override
    public void onDetachedFromRecyclerView(RecyclerView recyclerView) {
        super.onDetachedFromRecyclerView(recyclerView);
        subViewQueue.clear();//清空容器释放内存
        subViewQueue = null;
    }
}
```

### holder
```java
public abstract class CacheSubHolder<ITEMBEAN,SUBBEAN> extends BaseHolder<ITEMBEAN> {
    protected Queue<View> subViewQueue;
    protected  View mFirstSub;
    protected List<SUBBEAN> subDataList;
    protected ViewGroup container;
    protected Context mContext;
    private static final String TAG = "CacheSubHolder";

    public CacheSubHolder(View itemView,Context context) {
        super(itemView);
        mContext = context;
        container = itemView.findViewById(getSubListContainerID());
        mFirstSub = subViewFactory();
        container.addView(mFirstSub);
    }

    private View subViewFactory() {
        return LayoutInflater.from(mContext).inflate(getSubLayoutId(), container, false);
    }

    @IdRes
    protected abstract int getSubListContainerID();

    @LayoutRes
    protected abstract int getSubLayoutId();

    public Queue<View> getSubViewQueue() {
        return subViewQueue;
    }

    public void setSubViewQueue(Queue<View> subViewQueue) {
        this.subViewQueue = subViewQueue;
    }

    
    @Override
    public void bindData(ITEMBEAN mBean, int position) {
        
       subDataList =  getSubDataList(mBean,position);

        if (subDataList.size() < container.getChildCount()) {
            int outCount = container.getChildCount() - subDataList.size();
            for (int i = 0; i < outCount; i++) {
                View childAt = container.getChildAt(container.getChildCount() - 1);
                container.removeView(childAt);
                subViewQueue.add(childAt);
                LogUtils.d(TAG, "bindData: 缓存了view = "+childAt+"  size = "+subViewQueue.size());
            }
        }
        for (int i = 0; i < subDataList.size(); i++) {
            if (i == 0) {
                bindSubViewData(mFirstSub, subDataList.get(i));//至少一个实现复用
                LogUtils.d(TAG, "bindData: 使用first sub View");
            } else {
                if (container.getChildAt(i) != null) {
                    bindSubViewData(container.getChildAt(i),subDataList.get(i));//使用容器自带
                    LogUtils.d(TAG, "bindData: 使用容器自带 sub View");
                } else if (!subViewQueue.isEmpty()) {
                    View view = subViewQueue.poll();
                    bindSubViewData(view, subDataList.get(i));//使用queue内缓存
                    container.addView(view);
                    LogUtils.d(TAG, "bindData: 使用queue内缓存 sub View");
                } else {
                    View view = subViewFactory();
                    bindSubViewData(view,subDataList.get(i));//新建
                    LogUtils.d(TAG, "bindData: 新建 sub View");
                    container.addView(view);
                }
            }
        }
        bindOtherData(mBean,position);
    }

    protected abstract void bindOtherData(ITEMBEAN mBean, int position);

    protected abstract void bindSubViewData(View subView, SUBBEAN subbean);

    protected abstract List<SUBBEAN> getSubDataList(ITEMBEAN mBean, int position);
}
```
初步测试只有在外部列表刚进入的时候会创建一些内部item,外部列表滑动一遍后不会再inflate 新的内部item.未在复杂的外部和内部item中测试.暂记于此.




