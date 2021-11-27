for i in range(0,80):
    position = i
    if i >= 60:
        position = 0x54 + (i - 60)
    elif i >= 40:
        position = 0x14 + (i - 40)
    elif i >= 20:
        position = 0x40 + (i - 20)
    print(f"{hex(position)},", end="")
