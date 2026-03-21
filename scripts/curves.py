q = int("1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab",16)
groupOrder = int("73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001",16)
G = (int("17F1D3A73197D7942695638C4FA9AC0FC3688C4F9774B905A14E3A3F171BAC586C55E83FF97A1AEFFB3AF00ADB22C6BB",16),int("08B3F481E3AAA0F1A09E30ED741D8AE4FCF5E095D5D00AF600DB18CB2C04B3EDD03CC744A2888AE40CAA232946C5E7E1",16))


#0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab     381 prime
#0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001                                     255 prime
#G is the generator point on the curve G and only has X and Y coordinates. So we will need to add the default Z coordinate (1) ourselves.