"""Create a portable SSIS project from the native teacher project structure.
Only structural elements are reused; encrypted/user-specific metadata is removed.
"""
from pathlib import Path
import xml.etree.ElementTree as E
import uuid

ROOT=Path(__file__).resolve().parents[3]
NS='www.microsoft.com/SqlServer/SSIS'
E.register_namespace('SSIS',NS)
def guid(): return '{'+str(uuid.uuid4()).upper()+'}'
for student in 'AB':
 name=f'STUDENT_{student}_ID_SSIS'
 dest=ROOT/'submission'/f'Student_{student}'/'ssis'/name
 dest.mkdir(parents=True,exist_ok=True)
 native=dest/'Master.dtsx'
 if not native.exists(): raise FileNotFoundError(native)
 package=E.parse(native).getroot()
 dts='{www.microsoft.com/SqlServer/Dts}'
 tree=E.parse(ROOT/'work/windows_results/teacher_project.dtproj')
 root=tree.getroot()
 for parent in root.iter():
  for child in list(parent):
   if child.tag==f'{{{NS}}}Property':
    key=child.get(f'{{{NS}}}Name')
    if key=='PasswordVerifier':child.text=''
    elif key in ('CreatorName','CreatorComputerName'):child.text='BISM2202'
 root.find('Database').text=None
 root.find('Database/Name').text=name+'.database'
 root.find('Database/FullPath').text=name+'.database'
 root.find('.//{'+NS+'}Project').set('{'+NS+'}ProtectionLevel','DontSaveSensitive')
 for p in root.findall('.//{'+NS+'}Project/{'+NS+'}Properties/{'+NS+'}Property'):
  key=p.get('{'+NS+'}Name')
  if key=='Name':p.text=name
  elif key in ('ID','VersionGUID'):p.text=guid()
  elif key=='ProtectionLevel':p.text='DontSaveSensitive'
 for p in root.findall('.//{'+NS+'}Package'):p.set('{'+NS+'}Name','Master.dtsx')
 for metadata in root.findall('.//{'+NS+'}PackageMetaData'):
  metadata.set('{'+NS+'}Name','Master.dtsx')
  for p in metadata.findall('.//{'+NS+'}Property'):
   key=p.get('{'+NS+'}Name')
   if key=='ProtectionLevel':p.text='0'
   elif key=='Name':p.text=package.get(dts+'ObjectName')
   elif key=='ID':p.text=package.get(dts+'DTSID')
   elif key=='VersionGUID':p.text=package.get(dts+'VersionGUID') or guid()
 root.find('.//TargetServerVersion').text='SQLServer2022'
 E.indent(tree,space='  ')
 tree.write(dest/(name+'.dtproj'),encoding='utf-8',xml_declaration=True)
 db=E.parse(ROOT/'work/windows_results/teacher_project.database')
 for el in db.getroot():
  if el.tag.split('}')[-1] in ('ID','Name'):el.text=name
 db.getroot().set('{http://schemas.microsoft.com/DataWarehouse/Designer/1.0}design-time-name',str(uuid.uuid4()))
 db.write(dest/(name+'.database'),encoding='utf-8',xml_declaration=True)
 (dest/'Project.params').write_text('<?xml version="1.0"?><SSIS:Parameters xmlns:SSIS="'+NS+'" />',encoding='utf-8')
 project_id=guid()
 (dest/(name+'.sln')).write_text(f'''Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.14.37710.0
MinimumVisualStudioVersion = 10.0.40219.1
Project("{{C9674DCB-5085-4A16-B785-4C70DD1589BD}}") = "{name}", "{name}.dtproj", "{project_id}"
EndProject
Global
 GlobalSection(SolutionConfigurationPlatforms) = preSolution
  Development|Default = Development|Default
 EndGlobalSection
 GlobalSection(ProjectConfigurationPlatforms) = postSolution
  {project_id}.Development|Default.ActiveCfg = Development
  {project_id}.Development|Default.Build.0 = Development
 EndGlobalSection
EndGlobal
''',encoding='utf-8')
 print(name)
