import numpy as np
from PIL import Image
rng=np.random.default_rng(173)
n=512;y,x=np.mgrid[0:n,0:n]/n
nearest=np.full((n,n),10.0);second=nearest.copy()
for i in range(7):
    for j in range(7):
        px=(i+rng.random())/7;py=(j+rng.random())/7
        dx=np.minimum(abs(x-px),1-abs(x-px));dy=np.minimum(abs(y-py),1-abs(y-py))
        d=np.sqrt(dx*dx+dy*dy)
        second=np.minimum(second,np.maximum(nearest,d));nearest=np.minimum(nearest,d)
edge=second-nearest
light=np.exp(-edge*155.0)*0.85+np.exp(-edge*48.0)*0.15
Image.fromarray(np.uint8(np.clip(light,0,1)*255)).save('assets/effects/caustics.png')
