import CoreGraphics

/// Undo/redo history of window frames, kept separately for each window.
///
/// Each entry records the frame before and after one Zuntrio action. Undo
/// restores `before`; redo restores `after`. A new action clears that
/// window's redo stack. History is bounded per window and in the number of
/// windows tracked (least recently used windows are forgotten), so closed
/// windows can't accumulate. Nothing is persisted.
///
/// Undo and redo are two-step: `nextUndo`/`nextRedo` peek, and the caller
/// commits with `didUndo`/`didRedo` only once the frame was actually applied,
/// so a failed restore leaves the history intact.
public struct WindowHistory<Key: Hashable> {
    public struct Entry: Sendable, Equatable {
        public var before: CGRect
        public var after: CGRect

        public init(before: CGRect, after: CGRect) {
            self.before = before
            self.after = after
        }
    }

    private struct Stacks {
        var undo: [Entry] = []
        var redo: [Entry] = []
    }

    public let depth: Int
    public let windowLimit: Int
    private var stacks: [Key: Stacks] = [:]
    /// Keys from least to most recently used.
    private var recency: [Key] = []

    public init(depth: Int = 50, windowLimit: Int = 30) {
        self.depth = max(1, depth)
        self.windowLimit = max(1, windowLimit)
    }

    public var trackedWindowCount: Int { stacks.count }

    public mutating func record(_ entry: Entry, for key: Key) {
        var window = stacks[key] ?? Stacks()
        window.undo.append(entry)
        if window.undo.count > depth { window.undo.removeFirst(window.undo.count - depth) }
        window.redo.removeAll()
        stacks[key] = window
        touch(key)
    }

    public func nextUndo(for key: Key) -> Entry? { stacks[key]?.undo.last }
    public func nextRedo(for key: Key) -> Entry? { stacks[key]?.redo.last }

    /// Moves the entry returned by `nextUndo` to the redo stack.
    public mutating func didUndo(for key: Key) {
        guard var window = stacks[key], let entry = window.undo.popLast() else { return }
        window.redo.append(entry)
        stacks[key] = window
        touch(key)
    }

    /// Moves the entry returned by `nextRedo` back to the undo stack.
    public mutating func didRedo(for key: Key) {
        guard var window = stacks[key], let entry = window.redo.popLast() else { return }
        window.undo.append(entry)
        stacks[key] = window
        touch(key)
    }

    public mutating func forget(_ key: Key) {
        stacks[key] = nil
        recency.removeAll { $0 == key }
    }

    private mutating func touch(_ key: Key) {
        recency.removeAll { $0 == key }
        recency.append(key)
        while recency.count > windowLimit {
            stacks[recency.removeFirst()] = nil
        }
    }
}

extension WindowHistory: Sendable where Key: Sendable {}
