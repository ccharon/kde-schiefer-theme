/*
 * Display order of the icon box. Windows of the same program stay together in the order
 * they were opened, so nothing moves when a window is clicked. The order of the programs
 * follows clusterMode:
 *   opening       = first opened window of the program
 *   app           = program name
 *   lastActivated = most recently used window of the program (frozen while the mouse is
 *                   over the box, see Section.qml)
 *   ""            = no programs (windows of an open group)
 * An open group shows its windows by use, but frozen when it opens: usageKeys() takes the
 * snapshot, ranks() follows it, windows opened later go to the end.
 * The TasksModel stays unsorted and the delegates keep their model row; ranks() only says
 * where each row is shown, so clicks always act on the right window.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
import QtQuick
import org.kde.taskmanager as TaskManager

QtObject {
    function indexAt(model, parentIndex, row) {
        return parentIndex && parentIndex.valid ? model.makeModelIndex(parentIndex.row, row) : model.makeModelIndex(row);
    }
    function rowCount(model, parentIndex) {
        // rowCount() takes no null; top level without an argument
        return !model ? 0 : parentIndex && parentIndex.valid ? model.rowCount(parentIndex) : model.rowCount();
    }
    // identity of a window that survives row changes
    function windowKey(model, idx) {
        return JSON.stringify(model.data(idx, TaskManager.AbstractTasksModel.WinIdList) ?? []);
    }
    function usedAt(model, idx) {
        const t = model.data(idx, TaskManager.AbstractTasksModel.LastActivated);
        return t ? (new Date(t).getTime() || 0) : 0;
    }

    // window keys under parentIndex, most recently used first (snapshot for ranks())
    function usageKeys(model, parentIndex) {
        const list = [];
        for (let row = 0; row < rowCount(model, parentIndex); ++row) {
            const idx = indexAt(model, parentIndex, row);
            list.push({ key: windowKey(model, idx), time: usedAt(model, idx), row: row });
        }
        list.sort((a, b) => b.time - a.time || a.row - b.row);
        return list.map(e => e.key);
    }

    // last use per program (key as in ranks()), to freeze the "lastActivated" order
    function clusterTimes(model) {
        const times = {};
        for (let row = 0; row < rowCount(model, null); ++row) {
            const idx = indexAt(model, null, row);
            const key = (model.data(idx, TaskManager.AbstractTasksModel.AppId) || model.data(idx, TaskManager.AbstractTasksModel.AppName)
                         || model.data(idx, Qt.DisplayRole) || "").toLowerCase();
            times[key] = Math.max(times[key] ?? 0, usedAt(model, idx));
        }
        return times;
    }

    // rank for each row under parentIndex (null = top level): result[row] = position.
    // snapshot: optional usageKeys() result that fixes the order within a program.
    // frozenTimes: optional clusterTimes() result used instead of the live times.
    function ranks(model, parentIndex, clusterMode, snapshot, frozenTimes) {
        const n = rowCount(model, parentIndex);
        const entries = [];
        const clusters = {};
        for (let row = 0; row < n; ++row) {
            const idx = indexAt(model, parentIndex, row);
            const appId = model.data(idx, TaskManager.AbstractTasksModel.AppId) || "";
            const appName = model.data(idx, TaskManager.AbstractTasksModel.AppName) || "";
            const title = model.data(idx, Qt.DisplayRole) || "";
            const pinned = snapshot ? snapshot.indexOf(windowKey(model, idx)) : -1;
            const e = { row: row, key: clusterMode ? (appId || appName || title).toLowerCase() : "",
                        pinned: pinned < 0 ? Number.MAX_SAFE_INTEGER : pinned };
            entries.push(e);
            const c = clusters[e.key] ?? (clusters[e.key] = { first: row, last: 0, name: (appName || title).toLowerCase() });
            c.last = Math.max(c.last, usedAt(model, idx));
        }
        entries.sort((a, b) => {
            if (a.key !== b.key) {
                const ca = clusters[a.key], cb = clusters[b.key];
                if (clusterMode === "app" && ca.name !== cb.name) return ca.name < cb.name ? -1 : 1;
                const la = frozenTimes?.[a.key] ?? ca.last, lb = frozenTimes?.[b.key] ?? cb.last;
                if (clusterMode === "lastActivated" && la !== lb) return lb - la;
                return ca.first - cb.first;
            }
            return a.pinned - b.pinned || a.row - b.row;
        });
        const result = new Array(n);
        entries.forEach((e, pos) => result[e.row] = pos);
        return result;
    }
}
