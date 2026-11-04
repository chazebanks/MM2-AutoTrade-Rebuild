"""Analytic tradeoff figure; no observed acceptance model or price forecast."""
import os
os.environ.setdefault('MPLCONFIGDIR','/tmp/mm2-strategy-mpl')
os.environ.setdefault('XDG_CACHE_HOME','/tmp/mm2-strategy-font-cache')
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
plt.rcParams.update({'svg.hashsalt':'mm2-strategy-2026-11-04','font.size':10,'axes.spines.top':False,'axes.spines.right':False})
fig,axes=plt.subplots(1,2,figsize=(12,4.4),layout='constrained')
x=np.linspace(0,.8,180)
a=axes[0]
a.plot(x*100,1/(1-x),label='Same average attempt duration',color='#196b9c',lw=2)
a.plot(x*100,1.2/(1-x),label='20% longer duration (scenario)',color='#b75d22',lw=2,ls='--')
a.scatter([29/94*100,122/212*100],[94/65,212/90],c='#24333e',s=30,zorder=4)
a.annotate('94 → 65 profit\n1.45× threshold',(29/94*100,94/65),xytext=(7,2.6),arrowprops={'arrowstyle':'-','color':'#58636c'})
a.annotate('212 → 90 profit\n2.36× threshold',(122/212*100,212/90),xytext=(38,4.1),arrowprops={'arrowstyle':'-','color':'#58636c'})
a.set(xlabel='Conditional profit conceded (%)',ylabel='Required new / old completion-probability ratio',title='A better-looking quote must pay for its concession',ylim=(.9,6.5),xlim=(0,80))
a.grid(alpha=.2);a.legend(loc='upper left',fontsize=8)
b=axes[1];values=np.geomspace(2,5000,180)
b.loglog(values,1500/values,color='#277447',lw=2)
for value in (5,50,100,1000):
 y=1500/value;b.scatter([value],[y],color='#24333e',s=24)
 b.annotate(f'{y:g}%',(value,y),xytext=(5,5),textcoords='offset points')
b.set(xlabel='Our offer (Supreme value units)',ylabel='Required counterparty premium relative to our offer (%)',title='The fixed +15 floor is a larger hurdle at small values')
b.grid(alpha=.2,which='both')
fig.suptitle('Policy arithmetic — not measured MM2 acceptance or realized returns',fontsize=13)
fig.savefig(ROOT/'STRATEGY_TRADEOFFS_2026-11-04.svg',metadata={'Date':None,'Description':'Analytic thresholds only. All compared plans must independently satisfy the approved +15 floor.'})
svg=ROOT/'STRATEGY_TRADEOFFS_2026-11-04.svg'
svg.write_text('\n'.join(line.rstrip() for line in svg.read_text().splitlines())+'\n')
fig.savefig('/tmp/mm2-strategy-tradeoffs.png',dpi=120)
print('PASS analytic figure generated; no empirical probability claims')
