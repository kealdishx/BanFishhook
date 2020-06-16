# BanFishhook

## 原理

根据 mach-o 的符号动态链接原理，让 `non-lazy/lazy symbol` 指针重新指向对应的 `symbol stub` 代码位置，起到在 runtime 的反 hook。

根据数据段的 `lazy symbol pointers` 指向的指令的特点，每个指针的值减去 `0x100000000` 可以得到一个文件偏移的值，0x7E74,0x7E38 … 而文件偏移值指向的是代码段 `stub helper` 的位置, 并且每个函数的指令格式都一样, 如下：

```asm
ldr w16 #xxxx0
b xxxx1
xxxx0
```

- xxxx0 表示 `ldr w16 #xxxx0` 指令位置 + 8 字节内存地址的数据
- xxxx1 表示 `symbol stub` 代码的位置

每个不同的符号，`xxxx0` 是不同的，但是 `xxxx1` 的位置是一样的。`xxxx0` 是 `Binding Info` 或者 `Lazy Binding Info` 区起始开始到符号信息的偏移。根据这个信息，就可以筛选出 `stub helper` 模板指令对应的符号了，从而将 `non/lazy symbol pointer` 从新指向对应的 `stub helper` 区代码地址，起到反 hook 的功能。

## 引用

[AntiFishHook](http://iosre.com/t/antihook/15741)