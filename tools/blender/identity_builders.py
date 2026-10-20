"""Named silhouettes replace the hashed generic animals in the original prototype.
Reference descriptions: Steal a Brainrot NOOB.WIKI, Fandom, and the in-game roster.
These are original stylized models, not extracted Roblox assets.
"""
import math
from voxel_lib import Vox, shade

W=(.98,.98,.96); K=(.07,.07,.09); GREEN=(.28,.65,.24); SKIN=(.92,.72,.53)

def cat_head(v, y, z, color, size=1.8):
    v.ball(0,y,z,size,size*.82,size*.78,color)
    for x in (-size*.34,size*.34):
        v.box(x,y+size*.43,z-.1,size*.30,size*.42,size*.26,color)
        v.box(x,y+size*.46,z+.08,size*.13,size*.20,.08,(.98,.63,.70))
    v.eyes(y+.06,z+size*.35,size*.23,size*.25)
    v.ball(0,y-.15,z+size*.43,.24,.2,.13,(.93,.49,.55))
    for x in (-1,1):
        v.box(x*size*.28,y-.21,z+size*.40,size*.3,.08,.1,W)

def toucan(v,a,b,name):
    v.ball(0,2.0,0,1.9,2.6,1.6,K)
    v.ball(0,1.8,.67,1.1,1.8,.22,W)
    v.ball(0,3.4,0,1.45,1.4,1.4,K)
    v.box(0,3.35,1.35,.75,.64,1.6,(1,.65,.06))
    v.box(0,3.35,2.02,.70,.60,.32,K)
    v.mirror_box(.80,2.1,-.1,.28,1.6,1.1,K)
    v.legs2(.45,.8,.22,(1,.66,.1))
    v.mirror_box(.45,.10,.3,.65,.2,.8,(1,.66,.1))
    for x in (-.4,.4):
        v.box(x,3.57,.65,.65,.43,.18,(1,.80,.15))
        v.box(x,3.57,.78,.48,.28,.08,K)
    v.box(0,3.59,.73,.28,.1,.15,(1,.8,.15))

def mole(v,a,b,name):
    v.ball(0,1.55,0,2.8,2.5,2.7,(.42,.44,.48))
    v.ball(0,2.65,.6,2.0,1.6,1.7,(.63,.65,.69))
    v.ball(0,2.5,1.55,.8,.65,.55,(.91,.61,.64))
    v.mirror_box(1.45,.65,1,.75,.45,.85,(.75,.76,.80))
    for x in (-1.65,-1.4,-1.15,1.15,1.4,1.65):
        v.box(x,.65,1.6,.16,.18,.4,W)
    v.eyes(2.95,1.1,.55,.32)

def frog_gangster(v,a,b,name):
    green=(.37,.67,.22)
    v.legs2(.60,1.65,.78,K)
    v.box(0,2.50,0,2.1,1.9,1.2,K)
    v.box(0,2.55,.65,1.3,1.5,.12,W)
    v.box(0,2.5,.77,.18,1.25,.14,(.7,.15,.15))
    v.ball(0,4.0,.1,2.2,1.7,1.65,green)
    v.eyes(4.42,.68,.66,.52)
    v.box(0,3.8,1.02,1.5,.14,.1,K)
    v.box(0,5.05,0,2.8,.22,2.0,K)
    v.box(0,5.4,-.10,1.75,.66,1.35,K)
    v.mirror_box(1.45,2.6,.1,.65,1.8,.65,K)
    v.ball(1.45,1.65,.1,.7,.55,.7,green)
    v.box(1.45,1.8,.8,.35,.4,1.5,(.22,.22,.25))

def cactus_hippo(v,a,b,name):
    v.legs4(.75,.8,1.1,(.20,.50,.25),.65)
    v.ball(0,2.15,0,2.7,2.5,2.7,(.40,.69,.36))
    v.ball(0,3.5,.6,2.5,1.7,2.0,(.43,.70,.39))
    v.ball(0,3.1,1.4,2.5,1.0,1.2,(.53,.77,.45))
    v.eyes(3.85,1.25,.72,.38)
    for x in (-.75,0,.75):
        for y in (1.8,2.4,3.0): v.box(x,y,1.28,.09,.24,.12,(.15,.35,.15))
    v.mirror_box(1.8,2.8,0,.6,1.8,.6,(.37,.65,.28))
    v.mirror_box(1.45,2.1,0,1.0,.6,.6,(.37,.65,.28))

def leafy_squirrel(v,a,b,name):
    v.legs2(.5,1.1,.5,(.42,.30,.18))
    v.mirror_box(.5,.2,.35,1.0,.4,1.5,(.42,.30,.18))
    v.ball(0,2.5,0,1.8,3.1,1.7,GREEN)
    v.ball(0,3.4,.7,1.45,1.3,1.1,(.66,.78,.40))
    v.eyes(3.6,1.1,.38,.48)
    for x,y,z in ((0,4.4,0),(-.75,4.0,0),(.75,4.1,0),(0,4.05,-.7)):
        v.ball(x,y,z,1.45,1.2,1.3,(.20,.50,.19))
    v.ball(0,2.7,-1.1,1.4,2.8,1.5,(.34,.49,.20))

def axolotl(v,a,b,name):
    pink=(1,.62,.72)
    v.legs2(.55,1.5,.55,K)
    v.box(0,2.4,0,1.8,1.8,1.0,K)
    v.ball(0,3.9,0,2.3,1.8,1.8,pink)
    v.eyes(4.0,.82,.55,.36)
    for side in (-1,1):
        for k in range(3):
            v.box(side*(1.25+.25*k),3.5+.5*k,0,.75,.25,.35,(.9,.25,.38))
    v.box(0,4.9,0,3.0,.18,2.0,K)
    v.box(0,5.18,0,1.7,.6,1.35,K)
    v.mirror_box(1.2,2.2,0,.55,1.6,.55,pink)

def winged_cat(v,a,b,name):
    blue=(.47,.75,.97)
    v.legs4(.6,.6,.8,blue,.4)
    v.ball(0,1.7,0,1.8,1.5,2.2,blue)
    cat_head(v,2.7,.75,blue)
    for side in (-1,1):
        for k in range(4): v.box(side*(1.1+k*.40),2.2+k*.3,-.1,.65,.28,1.8-k*.25,W)
    v.box(0,1.7,-1.5,.25,.25,1.5,blue)

def lemon_bird(v,a,b,name):
    yellow=(1,.87,.18)
    v.ball(0,1.8,0,2.4,2.5,2.0,yellow)
    v.ball(0,3.1,.4,1.5,1.4,1.3,yellow)
    v.box(0,3.0,1.2,.5,.4,.65,(1,.53,.1))
    v.mirror_box(1.3,1.9,0,.3,1.5,1.2,yellow)
    v.legs2(.45,.6,.25,(.74,.43,.13))
    v.eyes(3.3,.9,.36,.30)
    v.box(0,3.95,0,.35,.4,.35,GREEN)
    v.box(.4,4.03,0,.9,.18,.5,GREEN)

def coconut_penguin(v,a,b,name):
    v.ball(0,2.1,0,2.8,2.8,2.5,(.48,.29,.16))
    v.ball(0,2.0,1.05,1.9,2.0,.32,W)
    v.ball(0,3.8,.15,1.6,1.6,1.5,K)
    v.eyes(4.0,.78,.38,.4)
    v.box(0,3.65,1.05,.65,.32,.7,(1,.61,.08))
    v.mirror_box(1.5,2.2,0,.3,1.8,1.0,K)
    v.mirror_box(.6,.15,.25,.95,.3,1.1,(1,.61,.08))

def chef_crab(v,a,b,name):
    red=(.92,.28,.18)
    v.ball(0,1.3,0,3.0,1.4,2.4,red)
    for side in (-1,1):
        for k in range(3):
            v.box(side*(1.55+k*.15),.6,-.8+k*.8,1.5,.25,.24,red)
        v.box(side*2.0,1.6,1,.5,.5,1.8,red)
        v.ball(side*2.2,2.6,1.7,1.4,1.4,.8,red)
        v.erase_ball(side*2.2,2.9,1.9,.38,.9,1.0)
    v.eyes(2.1,1.0,.7,.5)
    v.box(0,2.5,0,1.4,.7,1.3,W)
    for x in (-.6,0,.6): v.ball(x,3.3,0,1.1,1.1,1.4,W)

def cactus_lion(v,a,b,name):
    v.legs4(.7,.8,1.2,GREEN,.65)
    v.ball(0,2.1,0,2.3,1.8,2.8,GREEN)
    v.ball(0,3.1,1.0,2.6,2.6,1.3,(.62,.42,.18))
    v.ball(0,3.1,1.55,1.9,1.8,.9,(.91,.68,.22))
    v.eyes(3.45,1.95,.45,.36)
    v.box(0,2.9,2.1,.4,.32,.3,K)
    for i in range(8): v.box(-.9+(i%4)*.6,2.8,-.9+(i//4)*.8,.12,.35,.12,(.16,.34,.12))
    v.box(0,2.0,-2.0,.28,.28,1.3,GREEN)

def melon_croc(v,a,b,name):
    green=(.26,.58,.20)
    v.legs4(.85,.85,.9,green,.55)
    v.ball(0,1.8,0,2.6,1.9,3.5,green)
    for k in range(-2,3): v.box(k*.4,2.35,0,.12,.9,2.7,(.11,.32,.11))
    v.box(0,2.0,2.1,1.3,.9,2.4,green)
    v.box(0,1.6,2.1,1.25,.25,2.35,(.80,.87,.34))
    v.eyes(2.65,1.7,.45,.38)
    for z in (1.7,2.3,2.9): v.mirror_box(.53,1.75,z,.14,.3,.14,W)
    v.box(0,1.55,-2.2,.65,.5,1.4,green)

def flamingo(v,a,b,name):
    pink=(1,.39,.56)
    v.legs2(.4,2.5,.19,pink)
    v.ball(0,3.5,0,2.4,2.6,2.1,(.91,.19,.32))
    for x in (-.6,0,.6):
        for y in (2.8,3.5,4.2): v.box(x,y,.95,.13,.19,.13,(1,.86,.44))
    v.box(0,5.0,.3,.55,2.3,.55,pink)
    v.ball(0,6.1,.6,1.2,1.1,1.1,pink)
    v.box(0,5.9,1.25,.45,.4,.9,K)
    v.eyes(6.2,1.0,.31,.28)
    v.mirror_box(.5,4.85,0,.9,.18,.75,GREEN)

def fridge_camel(v,a,b,name):
    v.legs4(.8,.8,1.7,(.63,.45,.27),.48)
    v.mirror_box(.8,.2,.8,.9,.4,1.25,K)
    v.box(0,3.0,0,2.3,3.0,2.2,(.85,.90,.91))
    v.box(0,3.6,1.12,2.15,.06,.1,(.48,.55,.59))
    v.box(.7,2.8,1.25,.14,.8,.15,(.2,.25,.28))
    v.box(.7,4.0,1.25,.14,.55,.15,(.2,.25,.28))
    v.ball(0,5.0,-.5,1.0,2.1,1.0,(.64,.46,.26))
    v.ball(0,5.9,.0,1.2,1.1,1.8,(.68,.50,.3))
    v.eyes(6.1,.72,.35,.32)
    v.mirror_box(.55,6.5,-.5,.35,.65,.3,(.65,.45,.25))

def pineapple_ape(v,a,b,name):
    v.legs2(.6,1.1,.65,(.60,.28,.11))
    v.ball(0,2.5,0,2.3,3.0,2.0,(.97,.70,.18))
    for x in (-.75,0,.75):
        for y in (1.5,2.2,2.9,3.6): v.box(x,y,1.0,.18,.18,.15,(.67,.41,.1))
    v.ball(0,4.1,.3,2.0,1.8,1.5,(.66,.29,.09))
    v.ball(0,4.0,1.05,1.4,1.1,.3,SKIN)
    v.eyes(4.2,1.15,.36,.35)
    v.mirror_box(1.55,2.5,0,.7,2.8,.7,(.65,.30,.11))
    for x in (-.6,0,.6): v.box(x,5.2,-.35,.35,1.5,.35,GREEN)

def toaster_rhino(v,a,b,name):
    gray=(.56,.59,.63)
    v.legs4(.75,.7,1.0,gray,.6)
    v.box(0,2.15,0,2.6,2.2,2.3,(.68,.7,.73))
    for x in (-.55,.55):
        v.box(x,3.2,-.25,.75,.12,1.7,K)
        v.box(x,3.65,-.25,.65,.95,1.45,(.92,.70,.34))
    v.ball(0,2.65,1.45,2.2,1.7,1.9,gray)
    v.box(0,3.5,2.1,.4,1.1,.4,(.86,.83,.72))
    v.eyes(3.15,2.08,.6,.32)

def goose_plane(v,a,b,name):
    v.box(0,2.1,0,1.6,1.4,4.0,(.60,.64,.55))
    v.mirror_box(2.0,2.1,0,3.1,.23,1.6,(.45,.50,.4))
    v.box(0,3.0,1.5,.75,2.0,.75,W)
    v.ball(0,4.0,1.6,1.3,1.3,1.4,W)
    v.box(0,3.85,2.6,.55,.35,1.0,(1,.57,.07))
    v.eyes(4.25,2.05,.32,.29)
    v.box(0,2.8,-2.0,.2,1.2,1.0,(.45,.5,.4))
    v.mirror_box(.65,.45,.4,.45,.9,.45,(1,.58,.06))

def zebra_melon(v,a,b,name):
    v.legs4(.75,.75,1.6,(.62,.44,.29),.4)
    v.ball(0,2.7,0,2.7,2.4,2.7,GREEN)
    for x in (-.8,-.4,0,.4,.8): v.box(x,2.75,1.25,.12,1.5,.12,(.1,.31,.12))
    v.box(0,4.1,.5,.85,2.1,.9,W)
    v.ball(0,5.05,.95,1.2,1.2,1.7,W)
    for y in (3.4,3.8,4.2,4.6): v.box(0,y,1.02,.9,.13,.12,K)
    v.box(0,4.85,1.9,.9,.55,.45,K)
    v.eyes(5.25,1.56,.35,.27)
    v.mirror_box(.4,5.85,.4,.24,.65,.30,W)

def gorilla_avocado(v,a,b,name):
    brown=(.37,.27,.17)
    v.legs2(.75,1.0,.75,brown)
    v.ball(0,2.5,0,3.0,3.5,2.2,(.34,.52,.19))
    v.ball(0,2.4,1.0,2.0,2.5,.35,(.73,.82,.41))
    v.ball(0,2.4,1.25,1.1,1.1,.35,(.40,.24,.12))
    v.mirror_box(1.8,2.1,.1,.85,2.9,.85,brown)
    v.ball(0,4.1,.4,2.0,1.7,1.6,brown)
    v.ball(0,3.9,1.0,1.35,.85,.45,(.60,.45,.30))
    v.eyes(4.4,1.1,.45,.34)

def orange_muscle(v,a,b,name):
    orange=(1,.47,.08)
    v.legs2(.6,2.0,.75,SKIN)
    v.mirror_box(.6,.2,.3,1.0,.4,1.3,(.95,.22,.16))
    v.ball(0,3.35,0,2.6,2.8,1.6,orange)
    v.ball(0,5.0,0,1.5,1.4,1.3,orange)
    v.mirror_box(1.65,3.5,0,1.1,2.1,1.0,SKIN)
    v.mirror_box(.65,3.9,.78,1.1,.8,.35,SKIN)
    v.box(0,5.9,0,.25,.5,.25,GREEN)
    v.box(.35,6.0,0,.7,.16,.45,GREEN)
    v.eyes(5.18,.6,.32,.26)

def sky_giraffe(v,a,b,name):
    blue=(.46,.70,.94)
    v.legs4(.65,.75,2.4,blue,.4)
    v.ball(0,3.3,0,2.0,1.9,2.6,blue)
    v.box(0,5.6,1.0,.85,4.5,.9,blue)
    v.ball(0,7.7,1.3,1.3,1.4,1.9,blue)
    v.eyes(8.0,2.0,.36,.3)
    v.mirror_box(.4,8.5,1.05,.18,.8,.18,(1,.82,.22))
    for x,y,z in ((.55,3.6,1),(-.4,3.1,1.2),(.5,6,1.45),(-.3,7,1.45),(0,4.5,1.5)):
        v.box(x,y,z,.35,.12,.12,W)
        v.box(x,y,z,.12,.35,.12,W)

def spider_chimp(v,a,b,name):
    v.ball(0,2.0,0,2.0,1.7,2.0,(.70,.63,.20))
    brown = (.44,.29,.16)
    face = (.79,.61,.42)
    v.ball(0,3.1,.3,1.9,1.8,1.6,brown)
    v.mirror_box(1.0,3.15,.3,.6,.7,.5,brown)
    v.ball(0,2.9,1.0,1.35,1.05,.45,face)
    v.mirror_box(.35,3.35,1.01,.68,.68,.24,face)
    v.eyes(3.35,1.17,.35,.27)
    v.box(0,2.62,1.24,.52,.10,.10,K)
    for side in (-1,1):
        for k in range(4):
            z=-1.0+k*.7
            v.box(side*1.65,1.6,z,2.1,.26,.26,(.39,.25,.13))
            v.box(side*2.6,.9,z,.26,1.6,.26,(.39,.25,.13))

def grape_octopus(v,a,b,name):
    purple=(.43,.19,.60)
    for x,y,z in ((0,3.8,0),(-.7,3.5,0),(.7,3.5,0),(0,4.5,0),(-.4,4.2,.6),(.4,4.2,.6)):
        v.ball(x,y,z,1.5,1.5,1.5,purple)
    for k in range(8):
        ang=k*math.pi/4
        v.box(math.cos(ang)*1.2,1.5,math.sin(ang)*1.2,.45,3.0,.45,purple)
        v.box(math.cos(ang)*1.65,.25,math.sin(ang)*1.65,1.0,.4,1.0,purple)
    v.eyes(3.9,1.2,.48,.44)
    v.box(0,5.4,0,.4,.8,.4,GREEN)
    v.box(.65,5.55,0,1.3,.2,.6,GREEN)

def statues(v,a,b,name):
    for side,col in ((-1,(.73,.75,.79)),(1,(.95,.72,.17))):
        x=side*1.45
        v.box(x,3.2,0,1.65,2.8,1.2,col)
        for y in (2.0,2.4,2.8,3.2,3.6,4.0): v.box(x,y,.65,1.7,.13,.12,shade(col,.75))
        v.ball(x,5.0,0,1.5,1.4,1.2,col)
        v.box(x-.5,1.0,0,.5,2.0,.5,W)
        v.box(x+.5,1.0,0,.5,2.0,.5,W)
        for xx in (x-.5,x+.5): v.box(xx,.55,.3,.7,.35,.9,K)
        v.box(x-.3,5.15,.65,.17,.22,.1,K)
        v.box(x+.3,5.15,.65,.17,.22,.1,K)

def nuclear_dino(v,a,b,name):
    green=(.37,.69,.18)
    v.legs2(.75,1.4,.9,green)
    v.ball(0,2.8,0,2.3,3.0,2.4,green)
    v.box(0,4.8,.7,2.1,1.6,2.5,green)
    v.box(0,4.35,1.3,1.8,.3,2.0,K)
    for x in (-.6,0,.6): v.box(x,4.45,2.1,.14,.4,.15,W)
    v.mirror_box(1.3,3.0,1,.5,.5,1.4,green)
    v.box(0,1.6,-2,.8,.7,2.5,green)
    v.ball(0,2.7,1.0,1.5,1.8,.3,(.89,.95,.24))
    for x,y in ((0,3.1),(-.42,2.55),(.42,2.55)): v.box(x,y,1.2,.4,.4,.1,K)
    v.eyes(5.05,1.77,.52,.35)

def group(v,a,b,name,builder):
    for x,z in ((-1.6,0),(1.6,0),(0,1.6)):
        mini=Vox(v.vs)
        builder(mini,a,b,name)
        for (i,j,k),c in mini.cells.items():
            v.box(x+(i+.5)*v.vs*.52,(j+.5)*v.vs*.52,z+(k+.5)*v.vs*.52,v.vs*.58,v.vs*.58,v.vs*.58,mini.palette[c])


def corn_dormouse(v,a,b,name):
    fur = (.64,.48,.31)
    v.legs4(.55,.60,.65,fur,.36)
    v.ball(0,1.65,0,1.75,1.8,2.6,(.98,.79,.19))
    for y in (1.1,1.5,1.9,2.3):
        for z in (-.7,-.25,.2,.65):
            v.mirror_box(.83,y,z,.16,.30,.32,(1,.9,.36))
    v.ball(0,2.4,1.25,1.8,1.65,1.8,fur)
    v.ball(0,2.1,2.0,1.05,.75,.75,(.83,.69,.48))
    v.ball(0,2.15,2.39,.33,.26,.20,K)
    v.mirror_box(.65,3.15,1.22,.75,.8,.3,fur)
    v.eyes(2.67,1.93,.51,.34)
    v.box(0,1.6,-1.8,.3,.3,1.5,fur)
    v.mirror_box(.42,.8,-.4,.48,1.3,1.45,GREEN)


def avocado_capybara(v,a,b,name):
    fur = (.60,.41,.26)
    v.legs4(.62,.63,.68,fur,.40)
    v.ball(0,1.8,0,2.3,2.4,2.8,(.28,.45,.12))
    v.ball(0,1.85,1.04,1.55,1.8,.30,(.83,.87,.43))
    v.ball(0,1.8,1.22,.9,1.0,.28,(.45,.24,.13))
    v.ball(0,3.1,.7,1.8,1.65,1.95,fur)
    v.box(0,2.94,1.65,1.5,.95,.8,fur)
    v.mirror_box(.58,3.98,.45,.48,.47,.36,fur)
    v.eyes(3.4,1.70,.48,.27)
    v.box(0,3.04,2.12,.70,.2,.1,(.30,.20,.13))


def salmon_cat(v,a,b,name):
    salmon = (.69,.73,.74)
    leg = (.92,.72,.56)
    v.legs4(.65,.85,1.8,leg,.42)
    v.ball(0,2.7,0,1.9,1.8,3.5,salmon)
    v.ball(0,2.5,.1,1.45,.65,3.4,(.95,.72,.65))
    v.box(0,3.5,-.15,.20,.85,1.0,(.41,.50,.54))
    v.box(0,2.7,-2.1,.35,1.5,1.0,(.42,.51,.55))
    cat_head(v,3.45,1.5,(.88,.53,.21),1.85)
    for x in (-.62,0,.62):
        v.box(x,3.7,2.18,.12,.48,.08,(.49,.28,.12))

def named_builder(name, defaults):
    custom={
        'Fluriflura':toucan,'Talpa Di Fero':mole,'Gangster Footera':frog_gangster,
        'Cacto Hipopotamo':cactus_hippo,'Tric Trac Baraboom':leafy_squirrel,'Bandito Axolito':axolotl,
        'Gato Celesto':winged_cat,'Perochello Lemonchello':lemon_bird,'Penguino Cocosino':coconut_penguin,
        'Chef Crabracadabra':chef_crab,'Lionel Cactuseli':cactus_lion,'Glorbo Fruttodrillo':melon_croc,
        'Strawberrelli Flamingelli':flamingo,'Frigo Camelo':fridge_camel,'Orangutini Ananassini':pineapple_ape,
        'Rhino Toasterino':toaster_rhino,'Bombombini Gusini':goose_plane,'Zibra Zubra Zibralini':zebra_melon,
        'Avocadorilla':gorilla_avocado,'Odin Din Din Dun':orange_muscle,'Girafa Celestre':sky_giraffe,
        'Chimpanzini Spiderini':spider_chimp,'Graipuss Medussi':grape_octopus,'Garama and Madundung':statues,
        'Nuclearo Dinossauro':nuclear_dino,
        'Pipi Corni':corn_dormouse,'Pipi Avocado':avocado_capybara,'Trulimero Trulicina':salmon_cat,
    }
    if name=='Los Noobinis': return lambda v,a,b,n:group(v,a,b,n,defaults[0])
    if name=='Los Crocodillitos': return lambda v,a,b,n:group(v,a,b,n,defaults[15])
    if name=='Los Tralaleritos': return lambda v,a,b,n:group(v,a,b,n,defaults[16])
    return custom.get(name)

# Small starters, large long-neck and OG silhouettes. Feet remain at y=0.
TARGET_HEIGHTS={
    'Noobini Pizzanini':3.1,'Lirili Larila':4.7,'Tim Cheese':3.2,'Fluriflura':3.4,
    'Talpa Di Fero':2.6,'Svinina Bombardino':3.5,'Pipi Kiwi':2.8,'Pipi Corni':3.2,
    'Trippi Troppi':4.0,'Gangster Footera':4.6,'Bandito Bobritto':4.1,'Boneca Ambalabu':4.6,
    'Cacto Hipopotamo':4.8,'Tric Trac Baraboom':4.8,'Girafa Celestre':7.0,'Strawberrelli Flamingelli':6.0,
    'Bombardiro Crocodilo':4.4,'Glorbo Fruttodrillo':4.2,'Los Noobinis':3.5,'Los Crocodillitos':3.5,
    'Los Tralaleritos':3.5,'Gato Celesto':4.0,'Nuclearo Dinossauro':6.2,'Garama and Madundung':5.5,
    'Strawberry Elephant':7.2,'Odin Din Din Dun':5.8,'Frigo Camelo':5.8,
}
