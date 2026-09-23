use std;

struct Chunk {
    lo: int,
    hi: int,
    results: *Chan[ChunkResult],
}

struct ChunkResult {
    lo: int,
    hi: int,
    count: int,
}

fn count_range(c: *Chunk) {
    lim := 1;
    while lim * lim < c.hi {
        lim += 1;
    }
    m := lim + 1;
    base := new(u8, m);
    for i in 0..m {
        base[i] = 1;
    }
    base[0] = 0;
    base[1] = 0;
    p := 2;
    while p * p <= lim {
        if base[p] == 1 {
            j := p * p;
            while j <= lim {
                base[j] = 0;
                j += p;
            }
        }
        p += 1;
    }
    size := c.hi - c.lo;
    seg := new(u8, size);
    for i in 0..size {
        seg[i] = 1;
    }
    for p in 2..m {
        if base[p] == 1 {
            start := (c.lo + p - 1) / p * p;
            if start < p * p {
                start = p * p;
            }
            j := start;
            while j < c.hi {
                seg[j - c.lo] = 0;
                j += p;
            }
        }
    }
    count := 0;
    for i in 0..size {
        if seg[i] == 1 {
            count += 1;
        }
    }
    sys::chan_send(c.results, ChunkResult { lo: c.lo, hi: c.hi, count: count });
}

fn run_pool(workers: int, n: int, total_out: *int) -> int {
    results := sys::chan_new[ChunkResult]();
    chunks := new(Chunk, workers);
    ts := new(*Thread, workers);
    step := (n - 2 + workers - 1) / workers;
    lo := 2;
    t0 := sys::mono_ms();
    for i in 0..workers {
        hi := lo + step;
        if hi > n {
            hi = n;
        }
        chunks[i] = Chunk { lo: lo, hi: hi, results: results };
        ts[i] = sys::thread(count_range, &chunks[i]);
        lo = hi;
    }
    total := 0;
    for _i in 0..workers {
        r := ChunkResult { lo: 0, hi: 0, count: 0 };
        sys::chan_recv(results, &r);
        std::println_str(std::format("  [{}..{}): {} primes", r.lo, r.hi, r.count));
        total += r.count;
    }
    for i in 0..workers {
        sys::join(ts[i]);
    }
    ms := sys::mono_ms() - t0;
    sys::chan_free(results);
    *total_out = total;
    return ms;
}

fn main() -> int {
    defer std::println_str("(done - all memory freed automatically, zero leaks)");

    n := 2000000;
    expected := 148933;
    std::println_str("== parallel prime counter ==");
    std::println_str(std::format("counting primes below {}", n));
    std::println_str("");
    total := 0;

    std::println_str("[1 thread]");
    seq_ms := run_pool(1, n, &total);
    std::println_str(std::format("total: {} primes in {} ms", total, seq_ms));
    if total != expected {
        std::println_str(std::format("MISMATCH: expected {}", expected));
        sys::exit(1);
    }
    std::println_str("");

    std::println_str("[8 threads]");
    par_ms := run_pool(8, n, &total);
    std::println_str(std::format("total: {} primes in {} ms", total, par_ms));
    if total != expected {
        std::println_str(std::format("MISMATCH: expected {}", expected));
        sys::exit(1);
    }
    std::println_str("");

    denom := par_ms;
    if denom < 1 {
        denom = 1;
    }
    ratio := seq_ms as float / denom as float;
    std::println_str(std::format("speedup: {}x", ratio));
    return 0;
}

test "worker counts primes in range" {
    ch := sys::chan_new[ChunkResult]();
    c := Chunk { lo: 2, hi: 100, results: ch };
    count_range(&c);
    r := ChunkResult { lo: 0, hi: 0, count: 0 };
    assert(sys::chan_recv(ch, &r));
    assert_eq(r.count, 25);
    sys::chan_free(ch);
}

test "pool of two sums correctly" {
    total := 0;
    run_pool(2, 1000, &total);
    assert_eq(total, 168);
}

test "empty channel reports drained" {
    ch := sys::chan_new[int]();
    sys::chan_close(ch);
    v := 0;
    assert(!sys::chan_recv(ch, &v));
    sys::chan_free(ch);
}
