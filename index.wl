use std;

struct Word {
    text: string,
    count: int,
}

fn is_word_byte(c: u8) -> bool {
    return (c >= 97 && c <= 122) || (c >= 48 && c <= 57);
}

fn extract_words(text: string) -> Vec[string] {
    words := vec_new[string]();
    start := -1;
    i := 0;
    while text[i] != 0 {
        if is_word_byte(text[i]) {
            if start == -1 {
                start = i;
            }
        } else {
            if start != -1 {
                words.push(str_sub(text, start, i - start));
                start = -1;
            }
        }
        i += 1;
    }
    if start != -1 {
        words.push(str_sub(text, start, i - start));
    }
    return words;
}

fn by_count(a: Word, b: Word) -> int {
    if a.count > b.count {
        return -1;
    }
    if a.count < b.count {
        return 1;
    }
    return str_cmp(a.text, b.text);
}

fn sieve(limit: int) -> int {
    n := limit + 1;
    flags := new(u8, n);
    for i in 0..n {
        flags[i] = 1;
    }
    flags[0] = 0;
    flags[1] = 0;
    i := 2;
    while i * i <= limit {
        if flags[i] == 1 {
            j := i * i;
            while j < n {
                flags[j] = 0;
                j += i;
            }
        }
        i += 1;
    }
    count := 0;
    for i in 0..n {
        if flags[i] == 1 {
            count += 1;
        }
    }
    return count;
}

fn main() -> int {
    defer std::println_str("(selesai - semua memori dibebaskan otomatis, zero leaks)");

    arena(1 << 20) {
        text := "wlel is a fast simple systems language wlel compiles to c and c is fast "
              + "the arena is the syntax zero leaks zero gc fast as c simple as python "
              + "wlel is fast wlel is simple learn it in one afternoon fast fast c c c";

        words := extract_words(text);
        counts := map_new[string, int]();
        for w in words {
            counts.set(w, counts.get_or(w, 0) + 1);
        }

        items := vec_new[Word]();
        for k in counts.keys() {
            items.push(Word { text: k, count: counts.get(k) });
        }
        std::sort(items, by_count);

        std::println_str("== frekuensi kata ==");
        std::println_str(std::format("total kata: {}, unik: {}", words.len(), items.len()));
        std::println_str("");
        top := items.get(0).count;
        rank := 1;
        for it in items {
            w := it.count * 30 / top;
            bar := str_sub("##############################", 0, w);
            std::println_str(std::format("{}. {} ({}) {}", rank, it.text, it.count, bar));
            rank += 1;
        }

        std::println_str("");
        std::println_str("== benchmark: sieve of eratosthenes ==");
        t0 := sys::mono_ms();
        primes := sieve(1000000);
        ms := sys::mono_ms() - t0;
        std::println_str(std::format("primes < 1.000.000: {} ({} ms)", primes, ms));
    }
    return 0;
}

test "extract words handles punctuation" {
    ws := extract_words("hello, world! hello 123 wlel");
    assert_eq(ws.len(), 5);
    assert_eq(ws.get(0), "hello");
    assert_eq(ws.get(1), "world");
    assert_eq(ws.get(3), "123");
    assert_eq(ws.get(4), "wlel");
}

test "sieve counts primes" {
    assert_eq(sieve(10), 4);
    assert_eq(sieve(100), 25);
}

test "sort by count desc with alpha tiebreak" {
    items := vec_new[Word]();
    items.push(Word { text: "a", count: 1 });
    items.push(Word { text: "b", count: 3 });
    items.push(Word { text: "c", count: 2 });
    std::sort(items, by_count);
    assert_eq(items.get(0).text, "b");
    assert_eq(items.get(0).count, 3);
    assert_eq(items.get(2).text, "a");
}
