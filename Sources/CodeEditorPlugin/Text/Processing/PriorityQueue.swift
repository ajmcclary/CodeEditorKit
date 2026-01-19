import Foundation

// MARK: - Priority Queue

/// Generic heap-based priority queue for scheduling tasks
/// Extracted from AsyncTextProcessor for reusability and testability
internal struct PriorityQueue<T: Comparable> {
    private var heap: [T] = []

    var count: Int { heap.count }
    var isEmpty: Bool { heap.isEmpty }

    mutating func enqueue(_ element: T) {
        heap.append(element)
        heapifyUp(from: heap.count - 1)
    }

    mutating func dequeue() -> T? {
        guard !heap.isEmpty else { return nil }

        if heap.count == 1 {
            return heap.removeLast()
        }

        let value = heap[0]
        heap[0] = heap.removeLast()
        heapifyDown(from: 0)
        return value
    }

    mutating func remove(where predicate: (T) -> Bool) {
        heap.removeAll(where: predicate)
        // Rebuild heap
        let elements = heap
        heap = []
        for element in elements {
            enqueue(element)
        }
    }

    mutating func clear() {
        heap.removeAll()
    }

    func peek() -> T? {
        heap.first
    }

    private mutating func heapifyUp(from index: Int) {
        var childIndex = index
        let child = heap[childIndex]
        var parentIndex = (childIndex - 1) / 2

        while childIndex > 0 && heap[parentIndex] < child {
            heap[childIndex] = heap[parentIndex]
            childIndex = parentIndex
            parentIndex = (childIndex - 1) / 2
        }

        heap[childIndex] = child
    }

    private mutating func heapifyDown(from index: Int) {
        var parentIndex = index

        while true {
            let leftChildIndex = 2 * parentIndex + 1
            let rightChildIndex = leftChildIndex + 1
            var largestIndex = parentIndex

            if leftChildIndex < heap.count && heap[leftChildIndex] > heap[largestIndex] {
                largestIndex = leftChildIndex
            }

            if rightChildIndex < heap.count && heap[rightChildIndex] > heap[largestIndex] {
                largestIndex = rightChildIndex
            }

            if largestIndex == parentIndex {
                break
            }

            heap.swapAt(parentIndex, largestIndex)
            parentIndex = largestIndex
        }
    }
}
