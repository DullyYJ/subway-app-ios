import sys, re
# osascript 가 준 시뮬레이터 창 {x, y, 너비, 높이} → 허용 버튼 화면 좌표(잠금화면 '허용' 위치 근사)
n = [float(v) for v in re.findall(r'-?\d+(?:\.\d+)?', sys.argv[1])]
if len(n) >= 4:
    x, y, w, h = n[:4]
    top = 28
    ch = h - top
    print(int(x + w * 0.69), int(y + top + ch * 0.80))
