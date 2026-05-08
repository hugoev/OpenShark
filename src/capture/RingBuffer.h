#pragma once
#include <atomic>
#include <vector>
#include <optional>
#include <cstddef>

// Single-producer single-consumer lock-free ring buffer.
// Producer: capture thread. Consumer: UI drain thread.
template<typename T, std::size_t Capacity>
class RingBuffer
{
    static_assert((Capacity & (Capacity - 1)) == 0, "Capacity must be power of two");

public:
    bool push(T item) {
        const auto head = m_head.load(std::memory_order_relaxed);
        const auto next = (head + 1) & (Capacity - 1);
        if (next == m_tail.load(std::memory_order_acquire))
            return false; // full — drop packet
        m_buf[head] = std::move(item);
        m_head.store(next, std::memory_order_release);
        return true;
    }

    std::optional<T> pop() {
        const auto tail = m_tail.load(std::memory_order_relaxed);
        if (tail == m_head.load(std::memory_order_acquire))
            return std::nullopt;
        T item = std::move(m_buf[tail]);
        m_tail.store((tail + 1) & (Capacity - 1), std::memory_order_release);
        return item;
    }

    // Drain up to `max` items into `out`. Returns count drained.
    std::size_t drain(std::vector<T> &out, std::size_t max) {
        std::size_t count = 0;
        while (count < max) {
            auto item = pop();
            if (!item) break;
            out.push_back(std::move(*item));
            ++count;
        }
        return count;
    }

private:
    alignas(64) std::atomic<std::size_t> m_head{0};
    alignas(64) std::atomic<std::size_t> m_tail{0};
    std::vector<T> m_buf{Capacity};
};
