"""Part 1 schema diagram drawn from submitted DDL; no Part 2 visuals."""
from pathlib import Path
import re
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[2]
sql=(root/'scripts/windows/warehouse/schema.sql').read_text()
fields={}
for name,body in re.findall(r'CREATE TABLE dbo\.(\w+) \((.*?)\n\);',sql,re.S):
 columns=[]
 for line in body.splitlines():
  for seg in line.split(', '):
   m=re.match(r'\s*(\w+)\s+(bigint|int|smallint|tinyint|nvarchar\(\d+\)|datetime2|date|float|decimal\(19,4\))',seg)
   if m:
    column=m.group(1); prefix='PK ' if 'PRIMARY KEY' in seg else ('FK ' if name=='FactSales' and column.endswith('Key') else ('UK ' if column=='OrderItemID' else ''))
    columns.append(prefix+column+' : '+m.group(2))
 fields[name]=columns
fontroot=Path('/System/Library/Fonts/Supplemental')
body=ImageFont.truetype(str(fontroot/'Arial.ttf'),24)
heading=ImageFont.truetype(str(fontroot/'Arial Bold.ttf'),32)
title=ImageFont.truetype(str(fontroot/'Arial Bold.ttf'),42)
boxes={'DimCustomer':(45,150,675,545),'DimProduct':(45,620,675,1015),'DimSeller':(45,1090,675,1390),'FactSales':(870,150,1550,1150),'DimDate':(1745,150,2355,490),'DimGeography':(1745,570,2355,1070)}
for s in 'AB':
 im=Image.new('RGB',(2400,1500),'white');d=ImageDraw.Draw(im)
 d.text((650,42),f'STUDENT_{s}_ID OzMart sales star schema',font=title,fill='#173d58')
 for name,(x,y,x2,y2) in boxes.items():
  d.rounded_rectangle((x,y,x2,y2),radius=12,fill='#eef3f8',outline='#264c6c',width=3)
  d.text((x+20,y+16),name,font=heading,fill='#173d58')
  for n,col in enumerate(fields[name]):d.text((x+20,y+65+n*36),col,font=body,fill='#152738')
 for name in ('DimCustomer','DimProduct','DimSeller','DimDate'):
  x,y,x2,y2=boxes[name];left=x<870;start=(x2 if left else x,(y+y2)//2);end=(870 if left else 1550,(y+y2)//2)
  if name=='DimSeller':
   end=(870,1040);d.line((start,(770,start[1]),(770,1040),end),fill='#496879',width=4)
  else:d.line((start,end),fill='#496879',width=4)
  d.polygon([end,(end[0]+(-14 if left else 14),end[1]-9),(end[0]+(-14 if left else 14),end[1]+9)],fill='#496879')
 # Two distinct role-playing fact foreign keys to the same dimension.
 for offset,label in [(0,'CustomerGeographyKey'),(80,'SellerGeographyKey')]:
  y=730+offset;d.line(((1550,y),(1745,y)),fill='#496879',width=4)
  d.polygon([(1550,y),(1564,y-9),(1564,y+9)],fill='#496879')
 d.multiline_text((1745,1130),'Geography is role-playing.\nBoth fact geography keys reference\nDimGeography.GeographyKey.\n\nGrain: one original order item.\nPK SalesKey; unique OrderItemID.\nAll six fact foreign keys are required.',font=body,fill='#152738',spacing=12)
 dest=root/'submission'/f'Student_{s}'/'evidence/schema';dest.mkdir(parents=True,exist_ok=True)
 im.save(dest/f'STUDENT_{s}_ID_dm.png')
 print(s,{k:len(v) for k,v in fields.items()})
