# Gameplay References

## Table of contents

- [Player stats](#player-stats)
- [Apostles](#apostles)
- [Requirements](#requirements)

---

## Player Stats

| Kind | Description | Asset path |
|------|-------------|------------|
| **Served** (`Total_Served`) | Full serve: crowd member has fish and bread and enters post-serve | [assets/ui/people.png](assets/ui/people.png) |
| **Fish** (`Fish_Given`) | Fish handed out | [assets/fishes/fishes.png](assets/fishes/fishes.png) (atlas; cell index 0) |
| **Bread** (`Bread_Given`) | Bread handed out | [assets/breads/breads.png](assets/breads/breads.png) (atlas; cell index 0) |
| **Kids** (`Fed_Kids`) | Kid served | — (text label only) |
| **Young** (`Fed_Young`) | Young person served | — (text label only) |
| **Adults** (`Fed_Adults`) | Adult served | — (text label only) |
| **Distance** (`Distance_Walked`) | Horizontal pixels moved while walking | [assets/ui/sandals.png](assets/ui/sandals.png) |

---

## Apostles

| Name | Bonus | Unique behavior |
|------|-------|-----------------|
| Peter | + Speed | Runs to chunk 0 and back (3× sprint) |
| Andrew | + Speed | Visits adjacent chunk, escorts up to 5 crowd to player |
| James | + Speed | Celebration hops; may scare crowd in radius 88 pixels |
| John | + Range | Celebration hops; may draw crowd in radius 96 pixels |
| Philip | + Range | “Think” bubble with random fish * bread display |
| Bartholomew | + Stamina | Visits previous chunk, idles, returns |
| Thomas | + Recovery | Fade out / hidden / fade in |
| Matthew | + Stamina | Passive repel aura (radius 80 pixels) |
| Jude | + Recovery | Passive “???” bubbles |
| Thaddaeus | + Stamina | Passive “...” bubbles |
| Simon | + Range | Passive repel aura (radius 80 pixels) |
| Judas | — | Approaches fed-but-unserved crowd; coin talk; may grant bronze/silver or refuse |

---

## Requirements

| Stat kind | Low | High | Judas |
|-----------|-----|------|-------|
| Served | 80–200 | 250–600 | 1800–3500 |
| Fish / Bread | 60–180 | 200–500 | 500–1000 |
| Kids | 40–120 | 150–350 | 700–1200 |
| Young | 30–100 | 120–280 | 500–900 |
| Adults | 50–150 | 200–450 | 800–1500 |
| Dist | 3000–8000 | 10000–25000 | 40000–80000 |
