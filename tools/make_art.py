"""Rebuild the original, grid-authored SVG game art. No external assets."""
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
PALETTE = {'o':'111827','h':'28334c','H':'4b526a','s':'eeb491','S':'bf7e75','c':'52d6ae','C':'278982','p':'293955','P':'405675','w':'e2f5e5','g':'bfff81','b':'758dec','v':'9b7ce0','k':'090e1c'}
front = [
'......oooo......','.....ohhhho.....','....ohHHhhho....','....ohhhhhho....',
'....osssssso....','....osksksso....','.....ssssss.....','......SSSS......',
'....ooCCCCoo....','...occcwwccco...','...occcwwccco...','...occcggccco...',
'...osccccccso...','...oSCCCCCCSo...','....oppppppo....','....oppppppo....',
'....oppooppo....','....oppooppo....','....oPPooPPo....','....ooooooo.....']
back = [
'......oooo......','.....ohhhho.....','....ohHHhhho....','....ohhhhhho....',
'....ohhhhhho....','....ohhhhhho....','.....ohhhho.....','......SSSS......',
'....ooCCCCoo....','...ocCPPPPCco...','...ocPbbbbPco...','...ocPbwwbPco...',
'...osPbbbbPso...','...oSCPPPPCSo...','....oppppppo....','....oppppppo....',
'....oppooppo....','....oppooppo....','....oPPooPPo....','....ooooooo.....']
side = [
'......oooo......','.....ohhhho.....','.....ohHHhho....','.....ohhhhho....',
'.....ohsssso....','.....ohssko.....','......sssso.....','......SSSo......',
'.....oCCCoo.....','....occcccco....','....oCccocco....','....oCcsoCco....',
'....oCssoCco....','.....oCCCCo.....','.....oppppo.....','.....oppppo.....',
'.....opoppo.....','.....opoppo.....','.....oPoPPo.....','.....oooooo.....']

def svg(path, w, h, rects):
    path.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" shape-rendering="crispEdges">'+''.join(rects)+'</svg>')

def rect(x,y,w,h,color):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#{color}"/>'

for who,coat in [('hero','52d6ae'),('byte','e2e8d6'),('nova','9b7ce0'),('zero','758dec'),('kernel','d4a75a'),('alex','ec94a5')]:
    pal=PALETTE|{'c':coat}
    shapes=[]
    # Rows: down, left, right, up, working, celebrate, error, certificate/interview.
    for direction in range(8):
        base = back if direction==3 else (side if direction in (1,2) else front)
        if direction==1: base=[line[::-1] for line in base]
        for frame in range(4):
            for y,line in enumerate(base):
                for x,p in enumerate(line):
                    if p=='.': continue
                    bob = -1 if frame in (1,3) and direction<4 else 0
                    dx=0; dy=bob
                    if y>=16 and direction<4:
                        dy += (1 if x<8 else -1) * ([0,1,0,-1][frame])
                    if direction==5: dy -= 2 if frame in (1,2) else 0
                    if direction==6: dx=[0,-1,0,1][frame]
                    if direction==4 and p in 'sS' and y>10: dx = 1 if frame%2 else 0
                    shapes.append(rect(frame*16+x+dx,direction*24+y+2+dy,1,1,pal[p]))
            if direction==7:
                shapes += [rect(frame*16+5,direction*24+12,7,5,'fff1b8'),rect(frame*16+6,direction*24+13,5,1,'ba8b49')]
    svg(ROOT/'assets/sprites'/f'{who}.svg',64,192,shapes)

# Sixteen 32px tiles; authored with consistent material, light and edge details.
sh=[]
def r(tile,x,y,w,h,color): sh.append(rect(tile*32+x,y,w,h,color))
for t in range(16):
    if t<4:
        base=['223443','293c4b','38505b','302d49'][t]
        r(t,0,0,32,32,base); r(t,0,0,32,1,'526575');r(t,0,0,1,32,'405767')
        r(t,2,30,30,2,'182735');r(t,30,2,2,28,'182735')
        if t==2:
            for y in [7,15,23]: r(t,3,y,25,1,'49606a')
        else: r(t,5,5,2,2,'435867');r(t,25,25,2,2,'435867')
    elif t==4: # wall
        r(t,0,0,32,32,'172539');r(t,0,0,32,7,'728093');r(t,1,7,30,17,'49586f');r(t,3,9,26,2,'596a80');r(t,0,25,32,7,'101b30');r(t,2,25,28,2,'4fbcba')
    elif t==5: # desk
        r(t,2,5,28,20,'694f59');r(t,2,4,28,3,'be9a83');r(t,4,7,24,14,'99766c');r(t,3,25,4,6,'2b263a');r(t,25,25,4,6,'2b263a');r(t,6,9,20,1,'ac8778')
    elif t==6: # terminal on desk
        r(t,1,19,30,9,'a38177');r(t,1,19,30,2,'d5b098');r(t,4,2,24,18,'101c30');r(t,6,4,20,12,'35828d');r(t,7,5,18,2,'74dacc');r(t,8,9,10,1,'b8f3ce');r(t,8,12,14,1,'82d4cc');r(t,14,20,4,2,'2e3b52');r(t,7,24,18,3,'3f4c60');r(t,9,24,14,1,'b5c1be');r(t,3,28,4,4,'3e3042');r(t,25,28,4,4,'3e3042')
    elif t==7: # server
        r(t,3,0,26,32,'101c2d');r(t,4,1,24,3,'62718a');r(t,5,4,22,27,'29384f')
        for y in [6,13,20]:
            r(t,7,y,18,5,'152133');r(t,9,y+1,2,2,'67dfa8');r(t,13,y+1,8,1,'456078');r(t,13,y+3,8,1,'456078')
        r(t,6,29,20,2,'455671')
    elif t==8: # plant
        for x,y,w,h,c in [(8,21,16,8,'a4796b'),(6,20,20,3,'dbb497'),(11,28,10,3,'77525a'),(15,9,2,14,'52876b'),(4,9,10,5,'42806a'),(7,4,8,8,'69b486'),(16,3,8,10,'81c792'),(19,10,9,7,'4e9c78'),(9,13,12,7,'63b48b'),(10,5,3,4,'a0dc9f')]: r(t,x,y,w,h,c)
    elif t==9: # door
        r(t,0,0,32,32,'101b30');r(t,2,1,28,4,'82b4bf');r(t,4,5,11,27,'344d62');r(t,17,5,11,27,'344d62');r(t,6,7,7,19,'507486');r(t,19,7,7,19,'507486');r(t,14,8,4,20,'58dbb2');r(t,1,28,30,4,'c2d8cd')
    elif t==10: # chair
        r(t,7,6,18,10,'38456b');r(t,8,5,16,3,'7583ae');r(t,8,16,16,10,'4a5880');r(t,9,17,14,3,'65739d');r(t,10,26,3,5,'162439');r(t,20,26,3,5,'162439')
    elif t==11: # bed
        r(t,3,1,26,30,'947879');r(t,5,3,22,27,'697597');r(t,7,4,18,8,'d4dedb');r(t,5,14,22,14,'6d70af');r(t,5,14,22,3,'a29bd2');r(t,7,18,2,9,'8584bd')
    elif t==12: # bookcase
        r(t,1,0,30,32,'68535c')
        for y in [3,16]:
            r(t,3,y,26,10,'2b2b40')
            for i,c in enumerate(['72a99b','b98b7e','958dc5','cea56e','7092b1']):r(t,4+i*5,y+1,3,8,c)
            r(t,2,y+11,28,2,'b0907c')
    elif t==13: # rug
        r(t,0,0,32,32,'414362');r(t,0,0,32,1,'505170');r(t,0,30,32,2,'373953');r(t,5,8,1,1,'5b5a7e');r(t,21,24,1,1,'5b5a7e')
    elif t==14: # chip
        r(t,10,9,12,14,'dda960');r(t,12,11,8,10,'fff0a6');r(t,14,13,4,6,'b88a55')
        for y in [10,15,20]:r(t,7,y,3,2,'d2bc7d');r(t,22,y,3,2,'d2bc7d')
    elif t==15: # window
        r(t,1,0,30,32,'68728b');r(t,3,2,26,26,'16243b');r(t,5,4,22,22,'304a65');r(t,5,4,22,5,'476c80');r(t,15,2,2,26,'7b8da0');r(t,3,14,26,2,'7b8da0');r(t,0,28,32,4,'a9b4bb')
svg(ROOT/'assets/tilesets/academy.svg',512,32,sh)
