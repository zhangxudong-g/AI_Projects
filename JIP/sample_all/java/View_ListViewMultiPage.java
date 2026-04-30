/*
 * @(#)ListViewMultiPage.java
 *
 * Copyright (c) 2022 Japan Information Processing Service Co.,Ltd
 */
package jp.co.jip.jid0000.app.helper;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Iterator;
import java.util.Vector;

import jp.co.jip.jid0000.domain.util.JIDDebug;

/**
 * ページ制御を行う為の機能が追加されたViewオブジェクト。
 * 
 * @author zczl.dongyuan
 * @version JID_0.2.000.000 2022/05/18
 */
public class ListViewMultiPage implements ListViewInterface, Serializable {

    /**
     * serialVersionUID.
     */
    private static final long serialVersionUID = 1L;
    
    private int pageRowSize = Integer.MAX_VALUE;

    private Vector rows = new Vector();

    private int currentPage = 0;

    private Class rowClass = null;

    /**
     * 固定行表示を指定します。 カレント行イテレータが最大行数を必ず返すように する場合は空行オブジェクトとなるべきクラスを指定します。 nullが指定された場合、カレントイテレータは既存行までしか返しません。
     * 
     * @param rowClass 空行として返すオブジェクトのクラス
     */
    public void setFixedRowClass(Class rowClass) {
        this.rowClass = rowClass;
    }

    /**
     * カレントページイテレータが固定行を返すかを返します。
     * 
     * @return 最終ページ
     */
    public boolean isFixedRow() {
        return this.rowClass != null;
    }

    /**
     * ページ数を返します。 ここで返される値は最大表示行数と最大行より算出されます。
     * 
     * @return 最終ページ
     */
    public int getMaxPage() {
        int maxPage = 0;

        if (rows != null) {
            // 最大行数指定の場合
            maxPage = (int) (rows.size() / pageRowSize);
            if ((rows.size() % pageRowSize) > 0) {
                maxPage++;
            }
        }

        return maxPage;
    }

    /**
     * カレントページを次のページへ移します。 カレントページが最終ページである場合、 このメソッドは何も行いません。
     */
    public void nextPage() {
        int maxPage = getMaxPage();
        if (maxPage > currentPage) {
            currentPage++;
        }
    }

    /**
     * カレントページを前のページへ移します。 カレントページが最終ページである場合、 このメソッドは何も行いません。
     */
    public void prevPage() {
        int maxPage = getMaxPage();
        if (maxPage <= 0){
            return;
        }
        if (currentPage > 1) {
            currentPage--;
        }
    }

    /**
     * 任意のページをカレントページに設定します。
     * 
     * @param page ページ
     */
    public void setCurrentPage(int page) {
        int maxPage = getMaxPage();

        if (maxPage < page) {
            page = maxPage;
        } else if (rows.size() == 0) {
            page = 0;
        } else if (page < 1) {
            page = 1;
        }

        currentPage = page;
    }

    /**
     * 現在のカレントページ番号を返します。
     * 
     * @return カレントページ
     */
    public int getCurrentPage() {
        return currentPage;
    }

    /**
     * 現在のカレントが最終ページであるかを返します。
     * 
     * @return 最終ページである場合にtrueを返します。
     */
    public boolean isLastPage() {
        return getMaxPage() == currentPage;
    }

    /**
     * 現在のカレントが先頭ページであるかを返します。
     * 
     * @return 先頭ページである場合にtrueを返します。
     */
    public boolean isTopPage() {
        if (getMaxPage() == 0) {
            return true;
        } else {
            return currentPage == 1;
        }
    }

    /**
     * １ページに表示する最大表示行数を設定します。 ページ管理せず１ページに全行出力する場合は 0を指定します。
     * 
     * @param pageRowSize 1ページの最大行数
     */
    public void setPageRowSize(int pageRowSize) {
        if (pageRowSize < 1)
            pageRowSize = Integer.MAX_VALUE;
        this.pageRowSize = pageRowSize;
    }

    /**
     * １ページに表示する最大表示行数を返します。 このメソッドが0を返す場合はページ制御されません。
     * 
     * @return 1ページの最大行数
     */
    public int getPageRowSize() {
        if (pageRowSize == Integer.MAX_VALUE) {
            return 0;
        } else {
            return pageRowSize;
        }
    }

    /**
     * カレントページの行操作する為のイテレータを返します。
     * 
     * @return カレントページイテレータ
     */
    public Iterator getCurrentPageIterator() {
        if (currentPage == 0) {
            return new RowIterator(0);
        } else {
            return new RowIterator((currentPage - 1) * pageRowSize);
        }
    }

    /**
     * 現在表示可能なページ番号を返す為のイテレータ
     * 
     * @return ページコレクション
     */
    public Collection getPages() {
        ArrayList list = new ArrayList();
        for (int i = 0; i < getMaxPage(); i++) {
            list.add(String.valueOf(i + 1));
        }
        return list;
    }

    /**
     * 全行数を返します。
     * 
     * @return 行数
     */
    public int getRowSize() {
        return rows.size();
    }

    /**
     * カレントページの行操作する為のイテレータを返します。
     * 
     * @return カレントページイテレータ
     */
    public int getCurrentPageRowSize() {
        if (currentPage == 0) {
            return 0;
        } else {
            if (isLastPage()) {
                return rows.size() % pageRowSize;
            } else {
                return pageRowSize;
            }
        }
    }

    /**
     * 行を追加します。 ここで追加するオブジェクトは任意です。
     * 
     * @param rowData 行
     */
    public void addRow(Object rowData) {
        currentPage = 1;
        if (rowData != null) {
            rows.add(rowData);
        }
    }

    /**
     * 行をクリアします。
     */
    public void removeAll() {
        currentPage = 0;
        rows.clear();
    }

    /**
     * 指定されたインデックスの行を返します。
     * 
     * @param index 行 指定されたインデックス
     * @return Object 指定されたインデックスの行
     */
    public Object getRow(int index) {
        if (rows == null){
            return null;
        }
        return rows.get(index);
    }

    /**
     * カレントページの先頭からの指定されたインデックスの行を返します。
     * 
     * @param index 行 指定されたインデックス
     * @return Object 指定されたインデックスの行
     */
    public Object getCurrentPageRow(int index) {
        Object rowData = null;
        if (rows == null){
            return null;
        }
        Iterator iterator = this.getCurrentPageIterator();
        for (int i = 0; i < index + 1; i++) {
            if (!iterator.hasNext()){
                return null;
            }
            rowData = iterator.next();
        }
        return rowData;
    }

    /**
     * カレントページの行イテレータ
     * 
     * @author Crescent
     */
    private class RowIterator implements Iterator {
        private int startIndex = 0;

        private int position = 0;

        private Object dummy = null;

        private RowIterator(int startIndex) {
            this.position = startIndex - 1;
            this.startIndex = startIndex;
            if (isFixedRow()) {
                try {
                    dummy = rowClass.newInstance();
                } catch (Exception e) {
                    e.printStackTrace(JIDDebug.err);
                }
            }
        }

        /**
         * 次の行が存在するかを検査します。
         * 
         * @return boolean 次行が存在する場合にtrueを返します。
         */
        public boolean hasNext() {

            if (rows.size() > (position + 1)) {
                // 既に返却済みの行が最大行より小さい場合はtrue
                return ((position - startIndex + 1) < pageRowSize);
            } else {
                if (dummy != null && pageRowSize != Integer.MAX_VALUE) {
                    return ((((position + 1) % pageRowSize) != 0) || (rows
                            .size() == 0 && (position + 1) < pageRowSize));
                }
            }
            return false;
        }

        /**
         * 次の行を返します。
         * 
         * @return Object 次の行を返します。
         */
        public Object next() {
            Object result = null;
            if (hasNext()) {
                position++;
                if (position < rows.size()) {
                    result = rows.get(position);
                } else {
                    result = dummy;
                }
            }
            return result;
        }

        /**
         * 現在の行を削除します。
         */
        public void remove() {
            if (rows == null){
                return;
            }
            if (rows.size() > position && position >= startIndex) {
                rows.remove(position);
            }
        }
    }
}