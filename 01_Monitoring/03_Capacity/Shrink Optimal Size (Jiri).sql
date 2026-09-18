-- Script possible shrink size on databases of instance ( attached )
-- database free space recommended ( from 24% for small files to at least 10% for large files,  usually between 20% to above 10% )
-- %pct free space from UsedSpace
-- pctfree = 0.15*log(256GB)/log(UsedSpaceGB)  for UsedSpaceGB between 32GB and 4096GB, for UsedSpaceGB<=32GB = 0.24, for UsedSpaceGB>4096GB = 0.10
-- 1-pctfree = 1. - 0.15*log(256*1024)/log( isnull(cast(ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0) as bigint),0) )
 
-- Maximum Index Size per file group on datafiles
-- maximum Index Size from database on transactionlogfiles
 
/*
CurrentSizeUpMB - rounded up data file size in MB
UsedSpaceUpMB - space used by database objects from the data file in MB
FreeSpaceMB - free space in the data file
AddSpaceDbMb - recommended minimum free space in the data file for quick search of free pages or extents according to filling (based on statistics, for small files or filling up to 24%, for large files or filling more than 10%, on average around 15%).
AddSpaceIndexMB - recommended free space in the data file for rebuilding the largest index on the file group with equal distribution across all files of the file group.
OptimalSizeMB - optimal total size of the data file determined from UsedSpaceUpMB+max(AddSpaceDbMB, AddSpaceIndexMB) .
ShrinkSizeMB - possible space gain by shrinking the data file to OptimalSizeMB
*/

use tempdb
go
if object_id('dbo.#files', 'U') is not null  
   drop table #files;  
go  
create table #files  
( DbName nvarchar(128) not null
, type varchar(4) not null
, data_space_id int not null
, FileName nvarchar(256) not null
, CurrentSizeUpMB bigint not null
, UsedSpaceUpMB bigint not null
, FreeSpaceMB bigint not null
, AddSpaceDbMB bigint not null
, AddSpaceIndexMB bigint null
);  
 
exec sp_MSforeachdb N'
use [?]
insert into #files
select db_name() as DbName
     , case when type=0 then ''data'' else ''log'' end as type
     , data_space_id
     , name as FileName
     , isnull(cast(ceiling(size/128.0) as bigint),0) as CurrentSizeUpMB
     , isnull(cast(ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0) as bigint),0) as UsedSpaceUpMB
     , isnull(cast(ceiling(size/128.0) as bigint) - cast(ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0) as bigint),0) as FreeSpaceMB 
     , case 
       when isnull(cast(ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0) as bigint),0) <= 32*1024 
       then isnull(cast(ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0/(1.-0.24)) - ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0) as bigint),0)
when isnull(cast(ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0) as bigint),0) >= 4096*1024 
then isnull(cast(ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0/(1.-0.1)) - ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0) as bigint),0)
       else
isnull(cast(ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0/(1.-0.15*log(256*1024)/log( isnull(cast(ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0) as bigint),0) ))) - ceiling(cast(FILEPROPERTY(name,''SpaceUsed'') as bigint)/128.0) as bigint),0)
       end as AddSpaceDbMB
     , null
from sys.database_files
--where type = 0 --datafile
order by name;
'
 
exec sp_MSforeachdb N'
use [?]
;with AddIndex as
(select cast(ceiling(1.2*max(q.SpaceUsedMB)) as bigint) as AddSpaceIndexMB
from
(select 
    cast(ceiling(sum(isnull(total_pages,0) / 128.)) as bigint) as SpaceUsedMB,
    p.object_id,
    p.index_id,
    au.data_space_id
 from sys.partitions AS p
 inner join sys.allocation_units as au
    on p.partition_id = au.container_id
 where p.index_id between 1 and 254
 group by data_space_id, object_id, index_id
  ) q
),
Fls as
(select count(*) cnt
from sys.database_files
where type != 0
)
update #files set AddSpaceIndexMB =
(select cast(ceiling(a.AddSpaceIndexMB*1.0/f.cnt) as bigint) as AddSpaceIndexMB
from AddIndex a, Fls f
)
where DbName=N''?''
  and type=''log'';
'
 
exec sp_MSforeachdb N'
use [?]
;with AddIndex as
(select q.data_space_id, cast(ceiling(1.2*max(q.SpaceUsedMB)) as bigint) as AddSpaceIndexMB
from
(select 
    cast(ceiling(sum(isnull(total_pages,0) / 128.)) as bigint) as SpaceUsedMB,
    p.object_id,
    p.index_id,
    au.data_space_id
 from sys.partitions AS p
 inner join sys.allocation_units AS au
    on p.partition_id = au.container_id
 where p.index_id between 1 and 254
 group by data_space_id, object_id, index_id
 ) q
group by q.data_space_id
),
Fls as
(select data_space_id
      , count(*) cnt
from sys.database_files
where type = 0
group by data_space_id
)
update #files set AddSpaceIndexMB =
(select cast(ceiling(a.AddSpaceIndexMB*1.0/f.cnt) as bigint) as AddSpaceIndexMB
from AddIndex a
inner join Fls f on f.data_space_id=a.data_space_id
where a.data_space_id=#files.data_space_id)
where DbName=N''?''
  and type=''data'';
'
 
select * , UsedSpaceUpMB+iif(AddSpaceDbMB>AddSpaceIndexMB,AddSpaceDbMB,AddSpaceIndexMB) as OptimalSizeMB
, iif(CurrentSizeUpMB-(UsedSpaceUpMB+iif(AddSpaceDbMB>AddSpaceIndexMB,AddSpaceDbMB,AddSpaceIndexMB))>0,CurrentSizeUpMB-(UsedSpaceUpMB+iif(AddSpaceDbMB>AddSpaceIndexMB,AddSpaceDbMB,AddSpaceIndexMB)),0) as ShrinkSizeMB
--, round(iif(CurrentSizeUpMB-(UsedSpaceUpMB+iif(AddSpaceDbMB>AddSpaceIndexMB,AddSpaceDbMB,AddSpaceIndexMB))>0,CurrentSizeUpMB-(UsedSpaceUpMB+iif(AddSpaceDbMB>AddSpaceIndexMB,AddSpaceDbMB,AddSpaceIndexMB)),0)*100./CurrentSizeUpMB,2) as pctofCurrentSize
from #files
where DbName not in (N'master', N'msdb', N'tempdb', N'model', N'Admin')
--and type='data' --'log','data'
order by type, ShrinkSizeMB desc