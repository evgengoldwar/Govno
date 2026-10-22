#!/usr/bin/env python3
"""Builds data/world.json — the whole map of the game.

The world is a grid of cells (40x20 tiles each). Every room occupies
w x h cells and is placed at (gx, gy) on that grid; rooms share a global
tile coordinate system, so the game can switch rooms seamlessly.

Tiles:
  .  empty            #  solid           =  one-way platform
  B  wood/web (fire)  F  flame wall (water)
  G  grate (poison)   C  cracked stone (earth)
  X  seal gate (3 seals)
  ~  water            L  lava            T  toxic swamp
  ^  spikes

Run:  python3 tools/build_world.py [--preview out.png] [--check]
"""
import json
import os
import sys

CW, CH = 40, 20

ROOMS = {}
ORDER = []


class Room:
    def __init__(self, rid, name, biome, gx, gy, w=1, h=1):
        self.id, self.name, self.biome = rid, name, biome
        self.gx, self.gy, self.w, self.h = gx, gy, w, h
        self.W, self.H = w * CW, h * CH
        self.g = [['.'] * self.W for _ in range(self.H)]
        self.ents = []
        for x in range(self.W):
            self.g[0][x] = '#'
            self.g[self.H - 1][x] = '#'
        for y in range(self.H):
            self.g[y][0] = '#'
            self.g[y][self.W - 1] = '#'
        ROOMS[rid] = self
        ORDER.append(rid)

    def rect(self, x0, y0, x1, y1, ch='#'):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.g[y][x] = ch
        return self

    def floor(self, y=18):
        return self.rect(0, y, self.W - 1, self.H - 1)

    def plat(self, x0, x1, y):
        return self.rect(x0, y, x1, y, '=')

    def e(self, t, x, y, **kw):
        d = {'t': t, 'x': x, 'y': y}
        d.update(kw)
        self.ents.append(d)
        return self

    def coins(self, *pts):
        for p in pts:
            self.e('coin', p[0], p[1])
        return self


def hdoor(a, b, grow, gate=None, side='a'):
    """Opening between left room a and right room b, bottom row grow (global)."""
    A, B = ROOMS[a], ROOMS[b]
    assert A.gx + A.w == B.gx, (a, b)
    ra, rb = grow - A.gy * CH, grow - B.gy * CH
    assert 4 <= ra < A.H - 1 and 4 <= rb < B.H - 1, (a, b, ra, rb)
    for i in range(4):
        A.g[ra - i][A.W - 1] = gate if (gate and side == 'a') else '.'
        B.g[rb - i][0] = gate if (gate and side == 'b') else '.'


def vdoor(u, l, gcol, gate=None, lower_plat=True):
    """Opening between upper room u and lower room l at global columns gcol..gcol+3."""
    U, L = ROOMS[u], ROOMS[l]
    assert U.gy + U.h == L.gy, (u, l)
    cu, cl = gcol - U.gx * CW, gcol - L.gx * CW
    assert 1 <= cu and cu + 3 < U.W - 1 and 1 <= cl and cl + 3 < L.W - 1, (u, l)
    for i in range(4):
        U.g[U.H - 2][cu + i] = gate if gate else '.'
        U.g[U.H - 1][cu + i] = '='
        L.g[0][cl + i] = '.'
    if lower_plat:
        L.plat(max(1, cl - 2), min(L.W - 2, cl + 5), 3)


# ----------------------------------------------------------------------------
# CASTLE
# ----------------------------------------------------------------------------
r = Room('C1', 'Врата замка', 'castle', 1, 2, 2, 1).floor()
r.e('spawn', 5, 17).e('altar', 8, 17)
r.e('sign', 12, 17, text='← → идти, ▲ прыжок. Атакуй стихией — кнопка ✦.')
r.e('sign', 3, 17, text='Деревянный завал. Огонь сожжёт его.')
r.rect(20, 1, 21, 5).rect(44, 1, 45, 5).rect(60, 1, 61, 5)
r.plat(18, 24, 14).plat(27, 33, 11).rect(38, 15, 41, 17).plat(46, 52, 13).plat(56, 62, 10)
r.e('sign', 36, 17, text='Стихии переключаются кнопками вверху экрана.')
r.coins((21, 13), (30, 10), (49, 12), (58, 9), (60, 9))
r.e('slime', 30, 17).e('slime', 55, 17).e('bat', 70, 8)

r = Room('C0', 'Кладовая', 'castle', 0, 2).floor()
r.e('chest', 8, 17, id='c0', coins=20)
r.plat(14, 20, 14).plat(24, 30, 11)
r.coins((16, 13), (18, 13), (27, 10), (28, 10))
r.e('bat', 20, 6)

r = Room('C2', 'Двор', 'castle', 3, 2).floor()
r.plat(14, 19, 14).plat(23, 28, 10).plat(17, 22, 6)
r.e('sign', 20, 5, text='Слишком высоко... Здесь нужна сила ветра.')
r.e('sign', 10, 17, text='Внизу затопленный погреб. В форме воды можно плавать.')
r.e('sign', 33, 17, text='Пламенную стену погасит только вода.')
r.coins((19, 5), (21, 5), (25, 9))
r.e('archer', 26, 9).e('slime', 30, 17).e('bat', 8, 6)

r = Room('T1', 'Башня', 'castle', 3, 0, 1, 2)
r.rect(1, 38, 38, 38)
r.plat(4, 11, 31).plat(15, 22, 25).plat(26, 33, 19).plat(15, 22, 13).plat(12, 18, 9)
r.rect(1, 8, 9, 8)
r.plat(24, 31, 5)
r.e('chest', 28, 4, id='t1', coins=35)
r.coins((8, 30), (18, 24), (29, 18), (18, 12), (15, 8))
r.e('bat', 20, 30).e('bat', 15, 15).e('ghost', 30, 20).e('imp', 25, 6)

r = Room('T2', 'Шпиль', 'castle', 2, 0)
r.rect(1, 8, 38, 18)
r.rect(14, 7, 25, 7, '^').plat(18, 21, 4)
r.e('heart', 6, 7, id='h_t2')
r.coins((19, 3), (20, 3))
r.e('imp', 20, 2)

r = Room('C3', 'Большой зал', 'castle', 4, 2, 2, 1).floor()
r.rect(14, 1, 15, 6).rect(56, 1, 57, 6)
r.plat(38, 44, 14).plat(42, 47, 10).plat(33, 39, 7)
r.plat(60, 67, 14).plat(70, 76, 10)
r.e('chest', 73, 9, id='c3', coins=25)
r.coins((40, 13), (45, 9), (36, 6), (62, 13), (66, 13))
r.e('knight', 20, 17).e('archer', 64, 13).e('imp', 50, 6).e('bat', 10, 6).e('slime', 70, 17)
r.e('sign', 75, 17, text='Лавка торговца →')

r = Room('C5', 'Оружейная', 'castle', 4, 1).floor()
r.plat(4, 10, 12).plat(14, 20, 8)
r.e('chest', 17, 7, id='c5', coins=30)
r.coins((6, 11), (9, 11), (25, 17))
r.e('knight', 12, 17).e('knight', 22, 17).e('archer', 7, 11)

r = Room('C8', 'Галерея', 'castle', 5, 1).floor()
r.rect(14, 17, 25, 17, '^').plat(17, 22, 14)
r.coins((19, 13), (20, 13))
r.e('knight', 32, 17).e('imp', 20, 8).e('bat', 8, 6)
r.e('sign', 35, 17, text='Тронный зал. Страж огня боится воды.')

r = Room('B1', 'Тронный зал', 'castle', 6, 1).floor()
r.plat(6, 11, 13).plat(28, 33, 13).plat(16, 23, 9)
r.e('boss_warden', 30, 17)

r = Room('M1', 'Лавка', 'castle', 6, 2).floor()
r.plat(22, 27, 14).plat(30, 35, 10).plat(24, 29, 7)
r.e('merchant', 12, 17, shop='m1').e('altar', 6, 17)
r.e('sign', 18, 17, text='Монеты — у врагов и в сундуках. Наверху — тронный зал.')

r = Room('C6', 'Затопленный погреб', 'castle', 3, 3).floor()
r.rect(1, 6, 38, 17, '~')
r.rect(12, 10, 14, 17).rect(24, 6, 26, 12)
r.e('chest', 20, 17, id='c6', coins=30)
r.coins((8, 15), (28, 9), (33, 16))
r.e('piranha', 18, 12).e('piranha', 30, 14)

r = Room('C7', 'Темница', 'castle', 4, 3, 2, 1).floor()
r.rect(70, 1, 78, 12).rect(70, 13, 70, 17, 'G')
r.e('chest', 75, 17, id='c7', coins=45)
r.plat(56, 62, 13).plat(20, 26, 13)
r.e('sign', 46, 17, text='Решётка в полу. Её разъест только яд.')
r.coins((22, 12), (24, 12), (58, 12), (60, 12))
r.e('ghost', 30, 8).e('slime', 20, 17).e('knight', 38, 17).e('archer', 59, 12).e('slime', 64, 17)

r = Room('CR', 'Крипта', 'castle', 1, 3).floor()
r.plat(24, 29, 14).plat(18, 23, 10).plat(12, 17, 7)
r.rect(31, 17, 36, 17, '^')
r.e('heart', 37, 17, id='h_cr')
r.e('chest', 4, 17, id='cr', coins=25)
r.e('sign', 7, 17, text='Древняя крипта. Потолок здесь треснул.')
r.e('ghost', 30, 8).e('ghost', 10, 12)

# ----------------------------------------------------------------------------
# CAVES
# ----------------------------------------------------------------------------
r = Room('K1', 'Пещерный спуск', 'cave', 5, 4).floor()
r.plat(14, 19, 14).plat(20, 25, 10).plat(14, 19, 7)
r.e('sign', 30, 17, text='Подземелье пещер. Чем глубже, тем сильнее стихии.')
r.coins((16, 13), (22, 9), (17, 6))
r.e('spider', 30, 1).e('bat', 25, 6).e('slime', 34, 17)

r = Room('K2', 'Ядовитое болото', 'cave', 3, 4, 2, 1)
r.rect(1, 16, 69, 19).rect(70, 18, 78, 19)
r.rect(8, 16, 20, 17, 'T').rect(36, 16, 50, 17, 'T').rect(56, 16, 66, 17, 'T')
r.rect(30, 16, 33, 17, '.')
r.rect(1, 10, 6, 11)
r.plat(20, 25, 12).plat(10, 15, 8)
r.e('sign', 74, 17, text='Ядовитое болото. В форме яда отрава не вредит.')
r.coins((14, 13), (43, 13), (61, 13), (12, 7))
r.e('frog', 28, 15).e('frog', 54, 15).e('spider', 45, 1).e('bat', 60, 6).e('slime', 74, 17)

r = Room('K3', 'Кристальный грот', 'cave', 2, 4, 1, 2)
r.rect(30, 10, 38, 11).rect(1, 38, 38, 38)
r.plat(6, 12, 34).plat(14, 20, 30).plat(22, 28, 26).plat(30, 36, 22).plat(22, 28, 18).plat(28, 33, 14)
r.rect(1, 1, 11, 9).rect(11, 10, 11, 13, 'G').rect(1, 14, 11, 15)
r.plat(13, 19, 14)
r.e('chest', 5, 13, id='k3', coins=40)
r.coins((9, 33), (17, 29), (25, 25), (33, 21), (25, 17))
r.e('turret', 37, 30).e('bat', 25, 12).e('ghost', 15, 25).e('spider', 30, 1).e('frog', 20, 37)

r = Room('K5', 'Шахта', 'cave', 1, 4, 1, 3)
r.rect(26, 38, 38, 58).rect(1, 57, 25, 58)
r.rect(8, 56, 25, 56, '^')
r.plat(3, 8, 53).plat(10, 15, 49).plat(17, 22, 45).plat(20, 25, 41)
r.plat(20, 27, 31).plat(10, 17, 24).plat(18, 25, 17).plat(28, 35, 10)
r.e('chest', 3, 56, id='k5', coins=50)
r.e('sign', 32, 37, text='Шахта уходит вверх, к замку.')
r.coins((12, 48), (19, 44), (23, 30), (13, 23), (21, 16), (31, 9))
r.e('bat', 20, 20).e('bat', 10, 30).e('ghost', 30, 15).e('frog', 15, 55)

r = Room('M2', 'Пещерный лагерь', 'cave', 6, 4).floor()
r.rect(34, 6, 38, 17).plat(24, 29, 14)
r.e('merchant', 10, 17, shop='m2').e('altar', 17, 17)
r.e('sign', 26, 17, text='Выход наверху. Нужен двойной прыжок.')

r = Room('K7', 'Ветреный утёс', 'cave', 7, 4, 1, 2)
r.rect(1, 38, 38, 38).rect(1, 6, 6, 7)
r.plat(10, 15, 32).plat(22, 28, 26).plat(10, 16, 20).plat(22, 28, 14).plat(10, 15, 8)
r.plat(32, 37, 9)
r.e('chest', 34, 8, id='k7', coins=50)
r.e('sign', 30, 37, text='Ветреный утёс.')
r.coins((12, 31), (25, 25), (13, 19), (25, 13), (12, 7))
r.e('bat', 30, 20).e('bat', 15, 28).e('ghost', 25, 10).e('turret', 37, 30).e('frog', 30, 37)

r = Room('K8', 'Обрыв', 'cave', 7, 6).floor()
r.plat(26, 31, 14).plat(32, 36, 10).plat(26, 31, 7)
r.e('altar', 33, 17)
r.e('sign', 10, 17, text='Логово Колосса. Яд разъедает камень.')
r.e('frog', 18, 17)

r = Room('B3', 'Логово Колосса', 'cave', 5, 6, 2, 1).floor()
r.plat(14, 21, 12).plat(58, 65, 12).plat(34, 45, 8)
r.e('boss_colossus', 40, 17)

r = Room('K4', 'Паучье гнездо', 'cave', 3, 5, 2, 1).floor()
r.plat(36, 41, 14).plat(42, 47, 10).plat(33, 39, 7)
r.rect(1, 1, 10, 10).rect(10, 11, 10, 17, 'B')
r.e('chest', 5, 17, id='k4', coins=40)
r.e('altar', 74, 17)
r.e('sign', 70, 17, text='Логово королевы пауков. Огонь — её слабость.')
r.coins((38, 13), (44, 9), (36, 6), (60, 17))
r.e('spider', 20, 1).e('spider', 45, 1).e('spider', 62, 1).e('frog', 25, 17).e('bat', 55, 8).e('ghost', 64, 10)

r = Room('B2', 'Гнездо королевы', 'cave', 5, 5, 2, 1).floor()
r.plat(10, 17, 13).plat(62, 69, 13).plat(32, 47, 10)
r.e('boss_queen', 40, 3)

r = Room('K6', 'Глубины', 'cave', 3, 6, 2, 1).floor()
r.plat(40, 45, 14).plat(46, 51, 10).plat(40, 45, 7)
r.e('altar', 72, 17)
r.e('sign', 56, 17, text='Врата Ада. Откроются, когда соберёшь три печати стражей.')
r.coins((42, 13), (48, 9), (42, 6))
r.e('golem', 20, 17).e('ghost', 30, 8).e('frog', 10, 17)

r = Room('K9', 'Шипастый тоннель', 'cave', 2, 6).floor()
r.rect(4, 17, 33, 17, '^')
r.e('chest', 2, 17, id='k9', coins=60)
r.e('heart', 19, 12, id='h_k9')
r.e('sign', 36, 17, text='Каменная кожа земли не боится шипов.')
r.e('bat', 20, 6)

# ----------------------------------------------------------------------------
# HELL
# ----------------------------------------------------------------------------
r = Room('H1', 'Врата Ада', 'hell', 3, 7, 2, 1).floor()
r.plat(66, 71, 14).plat(60, 65, 10).plat(68, 73, 7)
r.rect(30, 18, 42, 18, 'L')
r.rect(1, 1, 14, 11).rect(14, 12, 14, 17, 'F')
r.e('chest', 6, 17, id='h1', coins=60)
r.e('altar', 52, 17)
r.e('sign', 56, 17, text='Ад. В форме огня лава не страшна.')
r.coins((33, 15), (36, 15), (39, 15))
r.e('hound', 22, 17).e('demon', 40, 6).e('imp', 25, 8)

r = Room('H2', 'Огненная река', 'hell', 5, 7, 2, 1).floor()
r.rect(8, 15, 71, 17, 'L')
r.rect(22, 14, 25, 17).rect(40, 14, 43, 17).rect(58, 14, 61, 17)
r.rect(50, 1, 51, 9).rect(50, 10, 51, 14, 'F')
r.coins((30, 11), (33, 11), (66, 11), (69, 11))
r.e('hound', 24, 13).e('demon', 32, 5).e('demon', 62, 5).e('skull', 45, 8)

r = Room('H3', 'Шипастый обрыв', 'hell', 7, 7, 1, 2)
r.rect(1, 18, 10, 19).rect(1, 38, 38, 38)
r.rect(12, 37, 38, 37, '^')
r.plat(13, 18, 34).plat(20, 25, 30).plat(28, 33, 26).plat(20, 25, 22).plat(12, 17, 19)
r.rect(30, 10, 38, 17).rect(30, 9, 38, 9, '^')
r.coins((15, 33), (22, 29), (30, 25), (22, 21))
r.e('wraith', 25, 12).e('skull', 20, 30).e('demon', 30, 5)

r = Room('H4', 'Ядовитые ямы', 'hell', 5, 8, 2, 1).floor()
r.rect(55, 18, 70, 18, 'T')
r.rect(40, 1, 41, 9).rect(40, 10, 41, 17, 'C')
r.rect(25, 1, 25, 11).rect(25, 12, 25, 17, 'B')
r.rect(8, 12, 20, 17)
r.coins((58, 15), (62, 15), (66, 15), (14, 11))
r.e('hound', 50, 17).e('wraith', 35, 8).e('skull', 15, 6).e('demon', 60, 5).e('frog', 30, 17)

r = Room('M3', 'Последний приют', 'hell', 4, 8).floor()
r.e('merchant', 20, 17, shop='m3').e('altar', 12, 17)
r.e('sign', 28, 17, text='Последний приют. Дальше — Владыка Бездны.')

r = Room('H5', 'Подступ к трону', 'hell', 3, 8).floor()
r.rect(10, 18, 20, 18, 'L')
r.rect(26, 1, 26, 12).rect(26, 13, 26, 17, 'F')
r.e('sign', 34, 17, text='Вода > Огонь > Яд > Земля > Ветер > Вода. Аура Владыки меняет стихию.')
r.e('demon', 15, 6).e('skull', 32, 8).e('wraith', 20, 8)

r = Room('BOSS', 'Трон Бездны', 'hell', 2, 8).floor()
r.plat(5, 11, 13).plat(28, 34, 13).plat(15, 24, 9)
r.e('boss_lord', 20, 7)

# ----------------------------------------------------------------------------
# CONNECTIONS
# ----------------------------------------------------------------------------
hdoor('C0', 'C1', 57, gate='B', side='b')
hdoor('C1', 'C2', 57)
hdoor('C2', 'C3', 57, gate='F', side='a')
vdoor('C2', 'C6', 3 * 40 + 4)
vdoor('T1', 'C2', 3 * 40 + 18, lower_plat=False)
hdoor('T2', 'T1', 7)
hdoor('C3', 'M1', 57)
vdoor('C5', 'C3', 4 * 40 + 30)
hdoor('C5', 'C8', 37)
hdoor('C8', 'B1', 37)
vdoor('B1', 'M1', 6 * 40 + 30)
hdoor('C6', 'C7', 77)
vdoor('C7', 'K1', 5 * 40 + 10, gate='G')
vdoor('C1', 'CR', 1 * 40 + 10, gate='C')
vdoor('CR', 'K5', 1 * 40 + 18)

hdoor('K1', 'M2', 97)
hdoor('K2', 'K1', 97)
hdoor('K3', 'K2', 89)
vdoor('K2', 'K4', 3 * 40 + 30)
hdoor('K4', 'B2', 117)
hdoor('K5', 'K3', 117)
hdoor('M2', 'K7', 85)
vdoor('K7', 'K8', 7 * 40 + 20)
hdoor('B3', 'K8', 137)
hdoor('B2', 'K7', 117)
vdoor('K4', 'K6', 4 * 40 + 10, gate='C')
hdoor('K9', 'K6', 137)
hdoor('K6', 'B3', 137, gate='C', side='b')
vdoor('K6', 'H1', 3 * 40 + 60, gate='X')

hdoor('H1', 'H2', 157)
hdoor('H2', 'H3', 157)
hdoor('H4', 'H3', 177)
hdoor('M3', 'H4', 177)
hdoor('H5', 'M3', 177)
hdoor('BOSS', 'H5', 177)

SHOPS = {
    'm1': [
        {'id': 'm1_heart', 'kind': 'heart', 'name': 'Сердце', 'desc': '+1 к здоровью', 'price': 60},
        {'id': 'm1_flask', 'kind': 'flask', 'name': 'Флакон', 'desc': '+1 лечебный флакон', 'price': 50},
        {'id': 'm1_dash', 'kind': 'dash', 'name': 'Рывок', 'desc': 'Быстрый рывок с неуязвимостью', 'price': 110},
        {'id': 'm1_power', 'kind': 'power', 'name': 'Искра силы', 'desc': '+25% урона стихиями', 'price': 90},
        {'id': 'm1_map', 'kind': 'map', 'name': 'Карта', 'desc': 'Открывает всю карту мира', 'price': 40},
    ],
    'm2': [
        {'id': 'm2_heart', 'kind': 'heart', 'name': 'Сердце', 'desc': '+1 к здоровью', 'price': 110},
        {'id': 'm2_flask', 'kind': 'flask', 'name': 'Флакон', 'desc': '+1 лечебный флакон', 'price': 90},
        {'id': 'm2_power', 'kind': 'power', 'name': 'Пламя силы', 'desc': '+25% урона стихиями', 'price': 160},
        {'id': 'm2_armor', 'kind': 'armor', 'name': 'Амулет стойкости', 'desc': 'Дольше неуязвим после удара', 'price': 130},
        {'id': 'm2_magnet', 'kind': 'magnet', 'name': 'Магнит', 'desc': 'Монеты летят к тебе издалека', 'price': 50},
    ],
    'm3': [
        {'id': 'm3_heart', 'kind': 'heart', 'name': 'Сердце', 'desc': '+1 к здоровью', 'price': 170},
        {'id': 'm3_heart2', 'kind': 'heart', 'name': 'Сердце Бездны', 'desc': '+1 к здоровью', 'price': 220},
        {'id': 'm3_power', 'kind': 'power', 'name': 'Звезда силы', 'desc': '+25% урона стихиями', 'price': 240},
        {'id': 'm3_flask', 'kind': 'flask', 'name': 'Флакон', 'desc': '+1 лечебный флакон', 'price': 150},
    ],
}


def export():
    rooms = []
    for rid in ORDER:
        R = ROOMS[rid]
        rooms.append({
            'id': R.id, 'name': R.name, 'biome': R.biome,
            'gx': R.gx, 'gy': R.gy, 'w': R.w, 'h': R.h,
            'tiles': [''.join(row) for row in R.g],
            'ents': R.ents,
        })
    return {'cell_w': CW, 'cell_h': CH, 'start': 'C1', 'rooms': rooms, 'shops': SHOPS}


# ----------------------------------------------------------------------------
# Validation: overlap + approximate reachability for each ability stage
# ----------------------------------------------------------------------------
SOLID = set('#BFGCX')
GATE_FOR = {'#': 'never', 'B': 'fire', 'F': 'water', 'G': 'poison', 'C': 'earth', 'X': 'seals'}
LIQ_FOR = {'~': 'water', 'L': 'fire', 'T': 'poison'}


def global_grid():
    cells = {}
    for R in ROOMS.values():
        ox, oy = R.gx * CW, R.gy * CH
        for y in range(R.H):
            for x in range(R.W):
                k = (ox + x, oy + y)
                assert k not in cells, ('overlap', R.id, k)
                cells[k] = R.g[y][x]
    return cells


def reach(cells, ab, start, single=5, double=9):
    J = double if 'air' in ab else single

    def blocked(c):
        t = cells.get(c, '#')
        if t in SOLID:
            return GATE_FOR[t] not in ab
        if t == '^':
            return 'earth' not in ab
        if t in 'LT':
            return LIQ_FOR[t] not in ab
        return False

    def support(c):
        t = cells.get(c, '#')
        if t == '=':
            return True
        if t in SOLID:
            return GATE_FOR[t] not in ab
        if t == '^':
            return 'earth' not in ab
        return False

    def swim(c):
        t = cells.get(c, '#')
        return t in LIQ_FOR and LIQ_FOR[t] in ab

    def node(c):
        return not blocked(c) and (support((c[0], c[1] + 1)) or swim(c))

    nodes = [c for c in cells if node(c)]
    nodeset = set(nodes)

    def clear_col(x, y0, y1):
        a, b = min(y0, y1), max(y0, y1)
        return all(not blocked((x, y)) for y in range(a, b + 1))

    def clear_row(y, x0, x1):
        a, b = min(x0, x1), max(x0, x1)
        return all(not blocked((x, y)) for x in range(a, b + 1))

    def edges(c):
        x, y = c
        out = []
        if swim(c):
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    n = (x + dx, y + dy)
                    if not blocked(n) and (n in nodeset or swim(n)):
                        out.append(n)
            above = (x, y - 1)
            if not swim(above) and not blocked(above):
                jh = J
            else:
                return out
        else:
            water = cells.get(c) == '~'
            jh = 1 if water else J
        for ty in range(y - jh, y + 22):
            for tx in range(x - 7, x + 8):
                t = (tx, ty)
                if t == c or t not in nodeset:
                    continue
                dy = ty - y
                dx = abs(tx - x)
                lim = 6 if dy <= 0 else 6 + dy // 2
                if dx > lim:
                    continue
                if dy <= 0:
                    ok = (clear_col(x, y, ty - 1 if ty - 1 >= y - jh else ty) and clear_row(ty - 1 if dy < 0 else ty, x, tx)) \
                        or (clear_row(y, x, tx) and clear_col(tx, y, ty))
                    if dy < 0 and not clear_col(tx, ty, ty - 1 if ty - 1 >= y - jh else ty):
                        ok = False
                else:
                    ok = (clear_row(y, x, tx) and clear_col(tx, y, ty)) or \
                         (clear_col(x, y, ty) and clear_row(ty, x, tx))
                if ok:
                    out.append(t)
        return out

    seen = {start}
    st = [start]
    adj = {}
    while st:
        c = st.pop()
        es = edges(c)
        adj[c] = es
        for n in es:
            if n not in seen:
                seen.add(n)
                st.append(n)
    # reverse reachability (softlock check)
    radj = {}
    for c, es in adj.items():
        for n in es:
            radj.setdefault(n, []).append(c)
    back = {start}
    st = [start]
    while st:
        c = st.pop()
        for p in radj.get(c, []):
            if p not in back:
                back.add(p)
                st.append(p)
    return seen, back


def check():
    cells = global_grid()
    sp = ROOMS['C1']
    start = (sp.gx * CW + 5, sp.gy * CH + 17)
    stages = [
        ('огонь+вода', {'fire', 'water'}),
        ('+яд', {'fire', 'water', 'poison'}),
        ('+ветер', {'fire', 'water', 'poison', 'air'}),
        ('+земля', {'fire', 'water', 'poison', 'air', 'earth'}),
        ('+печати', {'fire', 'water', 'poison', 'air', 'earth', 'seals'}),
    ]
    ok = True
    for name, ab in stages:
        seen, back = reach(cells, ab, start)
        rooms_seen = set()
        for R in ROOMS.values():
            ox, oy = R.gx * CW, R.gy * CH
            for e in R.ents:
                p = (ox + e['x'], oy + e['y'])
                # entity reachable if a node within 1 tile is reached
                hit = any((p[0] + dx, p[1] + dy) in seen for dx in (-1, 0, 1) for dy in (-1, 0, 1, 2))
                if hit:
                    rooms_seen.add(R.id)
        soft = seen - back
        soft_rooms = sorted({rid_of(c) for c in soft})
        print(f'[{name}] rooms: {len(rooms_seen)}/{len(ROOMS)} reachable: {sorted(rooms_seen)}')
        if soft:
            print(f'   SOFTLOCK cells: {len(soft)} in rooms {soft_rooms} e.g. {sorted(soft)[:5]}')
        last_seen = seen
    # final stage: every entity reachable
    for R in ROOMS.values():
        ox, oy = R.gx * CW, R.gy * CH
        for e in R.ents:
            if e['t'] in ('coin', 'heart'):
                p = (ox + e['x'], oy + e['y'])
                if any((p[0] + dx, p[1] + dy) in last_seen for dx in (-2, -1, 0, 1, 2) for dy in range(-1, 6)):
                    continue
            if e['t'] in ('bat', 'ghost', 'imp', 'demon', 'skull', 'wraith', 'spider', 'piranha', 'turret') or e['t'].startswith('boss'):
                continue
            p = (ox + e['x'], oy + e['y'])
            hit = any((p[0] + dx, p[1] + dy) in last_seen for dx in (-2, -1, 0, 1, 2) for dy in (-1, 0, 1, 2))
            if not hit:
                ok = False
                print('   UNREACHABLE:', R.id, e)
    return ok


def rid_of(c):
    for R in ROOMS.values():
        if R.gx * CW <= c[0] < (R.gx + R.w) * CW and R.gy * CH <= c[1] < (R.gy + R.h) * CH:
            return R.id
    return '?'


def preview(path):
    from PIL import Image, ImageDraw
    cells = global_grid()
    mx = max(c[0] for c in cells) + 1
    my = max(c[1] for c in cells) + 1
    s = 3
    img = Image.new('RGB', (mx * s, my * s), (10, 10, 16))
    d = ImageDraw.Draw(img)
    col = {'#': (90, 90, 110), '=': (160, 140, 100), 'B': (150, 90, 40), 'F': (255, 120, 40),
           'G': (120, 200, 80), 'C': (170, 140, 100), 'X': (220, 60, 220), '~': (40, 100, 220),
           'L': (240, 70, 20), 'T': (90, 200, 60), '^': (230, 230, 230), '.': (25, 25, 35)}
    for (x, y), t in cells.items():
        d.rectangle([x * s, y * s, x * s + s - 1, y * s + s - 1], fill=col.get(t, (255, 0, 255)))
    for R in ROOMS.values():
        ox, oy = R.gx * CW, R.gy * CH
        for e in R.ents:
            c = (255, 255, 0) if e['t'] in ('coin',) else (0, 255, 255) if e['t'] in ('chest', 'heart') else \
                (255, 255, 255) if e['t'] in ('altar', 'merchant', 'spawn', 'sign') else (255, 0, 0)
            x, y = ox + e['x'], oy + e['y']
            d.rectangle([x * s, y * s, x * s + s - 1, y * s + s - 1], fill=c)
    img.save(path)


if __name__ == '__main__':
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
    out = os.path.join(root, 'data', 'world.json')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w', encoding='utf-8') as f:
        json.dump(export(), f, ensure_ascii=False, separators=(',', ':'))
    print('wrote', out, len(ROOMS), 'rooms')
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
    if '--check' in sys.argv:
        sys.exit(0 if check() else 1)
