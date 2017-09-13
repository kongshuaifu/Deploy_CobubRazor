-- phpMyAdmin SQL Dump
-- version 4.4.14
-- http://www.phpmyadmin.net
--
-- Host: 127.0.0.1
-- Generation Time: 2017-07-25 17:25:53
-- 服务器版本： 5.6.26
-- PHP Version: 5.6.12

use razor_dw;

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `razor_dw`
--

DELIMITER $$
--
-- 存储过程
--
CREATE DEFINER=`admin`@`localhost` PROCEDURE `rundaily`(IN `yesterday` DATE)
    NO SQL
begin

declare csession varchar(128);
declare clastsession varchar(128);

declare cactivityid int;
declare clastactivityid int;

declare cproductsk int;
declare clastproductsk int;
declare s datetime;
declare e datetime;
declare single int;
declare endflag int;
declare seq int;
DECLARE col VARCHAR(16); 
DECLARE days INT; 
DECLARE d INT; 

declare usinglogcursor cursor

for

select product_sk,session_id,activity_sk from razor_fact_usinglog f, razor_dim_date d where f.date_sk = d.date_sk

and d.datevalue = yesterday;

declare continue handler for not found set endflag = 1;

set endflag = 0;

set clastactivityid = -1;
set single = 0;

insert into razor_log(op_type,op_name,op_starttime) 
    values('rundaily','-----start rundaily-----',now());

set s = now();

open usinglogcursor;

repeat

  fetch usinglogcursor into cproductsk,csession,cactivityid;

  if csession=clastsession then
      update razor_sum_accesspath set count=count+1 
      where product_sk=cproductsk and fromid=clastactivityid 
      and toid=cactivityid and jump=seq;
      
      if row_count()=0 then 
      insert into razor_sum_accesspath(product_sk,fromid,toid,jump,count)
      select cproductsk,clastactivityid,cactivityid,seq,1;
      end if;
    set seq = seq +1;

  else
     update razor_sum_accesspath set count=count+1 
     where product_sk=clastproductsk and fromid=clastactivityid 
     and toid=-999 and jump=seq;
     
     if row_count()=0 then 
     insert into razor_sum_accesspath(product_sk,fromid,toid,jump,count) 
     select clastproductsk,clastactivityid,-999,seq,1;
     end if;
     set seq = 1;

     end if;

   set clastsession = csession;
   set clastactivityid = cactivityid;
   set clastproductsk = cproductsk;

until endflag=1 end repeat;

close usinglogcursor;

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundaily','razor_sum_accesspath',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
set s = now();

-- generate the count of new users for yesterday

-- for channels, versions
INSERT INTO razor_sum_reserveusers_daily 
            (startdate_sk, 
             enddate_sk, 
             product_id, 
             version_name, 
             channel_name, 
             usercount) 
SELECT (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = yesterday)     startdate_sk, 
       (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = yesterday)       enddate_sk, 
       ifnull(p.product_id,-1), 
       ifnull(p.version_name,'all'),
       ifnull(p.channel_name,'all'), 
       Count(DISTINCT f.deviceidentifier) count 
FROM   razor_fact_clientdata f, 
       razor_dim_date d, 
       razor_dim_product p 
WHERE  f.date_sk = d.date_sk 
       AND d.datevalue = yesterday 
       AND f.product_sk = p.product_sk 
       AND p.product_active = 1 
       AND p.channel_active = 1 
       AND p.version_active = 1 
       AND f.isnew = 1 
GROUP  BY p.product_id, 
          p.version_name,
          p.channel_name with rollup
union
SELECT (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = yesterday)     startdate_sk, 
       (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = yesterday)       enddate_sk, 
       ifnull(p.product_id,-1), 
       ifnull(p.version_name,'all'),
       ifnull(p.channel_name,'all'), 
       Count(DISTINCT f.deviceidentifier) count 
FROM   razor_fact_clientdata f, 
       razor_dim_date d, 
       razor_dim_product p 
WHERE  f.date_sk = d.date_sk 
       AND d.datevalue = yesterday 
       AND f.product_sk = p.product_sk 
       AND p.product_active = 1 
       AND p.channel_active = 1 
       AND p.version_active = 1 
       AND f.isnew = 1 
GROUP  BY p.product_id, 
          p.channel_name,
          p.version_name with rollup
ON DUPLICATE KEY UPDATE usercount=VALUES(usercount);

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundaily','razor_sum_reserveusers_daily new users for app,version,channel dimensions',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));


set d = 1;
while d<=8 do
  begin
    set col = concat('day',d);

    set days = -d;
    
    set s = now();
    
    -- 8 days for app,channel, version
    SET @sql=concat(
        'insert into razor_sum_reserveusers_daily(startdate_sk, enddate_sk, product_id, version_name,channel_name,',
        col,
        ')
        Select 
        (select date_sk from razor_dim_date where datevalue= date_add(\'',yesterday,'\',interval ',days,' DAY)) startdate,
        (select date_sk from razor_dim_date where datevalue= date_add(\'',yesterday,'\',interval ',days,' DAY)) enddate,
        ifnull(p.product_id,-1),ifnull(p.version_name,\'all\'),ifnull(p.channel_name,\'all\'),
        count(distinct f.deviceidentifier)
        from
        razor_fact_clientdata f, razor_dim_date d, razor_dim_product p where f.date_sk = d.date_sk 
        and f.product_sk = p.product_sk and d.datevalue = \'',yesterday,'\' and p.product_active=1 
        and p.channel_active=1 and p.version_active=1 and exists 
         (select 1 from razor_fact_clientdata ff, razor_dim_product pp, razor_dim_date dd where ff.product_sk = pp.product_sk 
         and ff.date_sk = dd.date_sk and pp.product_id = p.product_id and dd.datevalue between 
         date_add(\'',yesterday,'\',interval ',days,' DAY) and 
         date_add(\'',yesterday,'\',interval ',days,' DAY) and ff.deviceidentifier = f.deviceidentifier and pp.product_active=1 
         and pp.channel_active=1 and pp.version_active=1 and ff.isnew=1) group by p.product_id,p.version_name,p.channel_name with rollup
         union
         Select 
        (select date_sk from razor_dim_date where datevalue= date_add(\'',yesterday,'\',interval ',days,' DAY)) startdate,
        (select date_sk from razor_dim_date where datevalue= date_add(\'',yesterday,'\',interval ',days,' DAY)) enddate,
        ifnull(p.product_id,-1),ifnull(p.version_name,\'all\'),ifnull(p.channel_name,\'all\'),
        count(distinct f.deviceidentifier)
        from
        razor_fact_clientdata f, razor_dim_date d, razor_dim_product p where f.date_sk = d.date_sk 
        and f.product_sk = p.product_sk and d.datevalue = \'',yesterday,'\' and p.product_active=1 
        and p.channel_active=1 and p.version_active=1 and exists 
         (select 1 from razor_fact_clientdata ff, razor_dim_product pp, razor_dim_date dd where ff.product_sk = pp.product_sk 
         and ff.date_sk = dd.date_sk and pp.product_id = p.product_id and dd.datevalue between 
         date_add(\'',yesterday,'\',interval ',days,' DAY) and 
         date_add(\'',yesterday,'\',interval ',days,' DAY) and ff.deviceidentifier = f.deviceidentifier and pp.product_active=1 
         and pp.channel_active=1 and pp.version_active=1 and ff.isnew=1) group by p.product_id,p.channel_name,p.version_name with rollup
        on duplicate key update ',col,'=values(',col,');');
        
    
    PREPARE sl FROM @sql;
    EXECUTE sl;
    DEALLOCATE PREPARE sl;
    
    set e = now();
    insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundaily',concat('razor_sum_reserveusers_daily DAY ',-d,' reserve users for app,channel,version dimensions'),s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
    
    set d = d + 1; 
  end;
end while;

set s = now();

insert into razor_sum_accesslevel(product_sk,fromid,toid,level,count)
select product_sk,fromid,toid,min(jump),sum(count) from razor_sum_accesspath group by product_sk,fromid,toid
on duplicate key update count = values(count);

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundaily','razor_sum_accesslevel',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
    
set s = now();


update razor_fact_clientdata a,razor_fact_clientdata b,razor_dim_date c,
razor_dim_product d,razor_dim_product f set a.isnew=0 where 
((a.date_sk>b.date_sk) or (a.date_sk=b.date_sk and a.dataid>b.dataid)) 
and a.isnew=1 
and a.date_sk=c.date_sk and c.datevalue between DATE_SUB(yesterday,INTERVAL 7 DAY) and yesterday
and a.product_sk=d.product_sk 
and b.product_sk=f.product_sk 
and a.deviceidentifier=b.deviceidentifier and d.product_id=f.product_id;

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundaily','razor_fact_clientdata recalculate new users',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
    
set s = now();


update razor_fact_clientdata a,razor_fact_clientdata b,razor_dim_date c,
razor_dim_product d,razor_dim_product f set a.isnew_channel=0 where 
((a.date_sk>b.date_sk) or (a.date_sk=b.date_sk and a.dataid>b.dataid)) 
and a.isnew_channel=1 
and a.date_sk=c.date_sk and c.datevalue between DATE_SUB(yesterday,INTERVAL 7 DAY) and yesterday
and a.product_sk=d.product_sk 
and b.product_sk=f.product_sk 
and a.deviceidentifier=b.deviceidentifier and d.product_id=f.product_id and d.channel_id=f.channel_id;

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundaily','razor_fact_clientdata recalculate new users for channel',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

insert into razor_log(op_type,op_name,op_starttime) 
    values('rundaily','-----finish rundaily-----',now());
    
end$$

CREATE DEFINER=`admin`@`localhost` PROCEDURE `rundim`()
    NO SQL
begin
declare s datetime;
declare e datetime;

insert into razor_log(op_type,op_name,op_starttime)
    values('rundim','-----start rundim-----',now());


/* dim location */
set s = now();

update razor_db.razor_clientdata
set region = 'unknown'
where (region = '') or (region is null);

update razor_db.razor_clientdata
set city = 'unknown'
where (city = '') or (city is null);

insert into razor_dim_location
           (country,
            region,
            city)
select distinct country,
                region,
                city
from   razor_db.razor_clientdata a
where  not exists (select 1
                   from   razor_dim_location b
                   where  a.country = b.country
                          and a.region = b.region
                          and a.city = b.city);
set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundim','razor_dim_location',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

/* dim devicebrand */
set s = now();
insert into razor_dim_devicebrand(devicebrand_name)
select distinct devicename
from   razor_db.razor_clientdata a
where  not exists (select 1
                   from   razor_dim_devicebrand b
                   where  a.devicename = b.devicebrand_name);
 insert into razor_dim_deviceos
           (deviceos_name)
select distinct osversion
from   razor_db.razor_clientdata a
where  not exists (select *
                   from   razor_dim_deviceos b
                   where  b.deviceos_name = a.osversion);
                   
set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundim','razor_dim_deviceos',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

/* dim devicelanguage */
set s = now();
insert into razor_dim_devicelanguage
           (devicelanguage_name)
select distinct language
from   razor_db.razor_clientdata a
where  not exists (select *
                   from   razor_dim_devicelanguage b
                   where  a.language = b.devicelanguage_name);
set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundim','razor_dim_devicelanguage',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

/* dim resolution */
set s = now();
insert into razor_dim_deviceresolution
           (deviceresolution_name)
select distinct resolution
from   razor_db.razor_clientdata a
where  not exists (select *
                   from   razor_dim_deviceresolution b
                   where  a.resolution = b.deviceresolution_name);
                   
set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundim','razor_dim_deviceresolution',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

/* dim devicesupplier */
set s = now();
insert into razor_dim_devicesupplier (mccmnc)
select distinct a.service_supplier
from   razor_db.razor_clientdata a
where  not exists (select *
                   from   razor_dim_devicesupplier b
                   where  a.service_supplier = b.mccmnc);

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundim','razor_dim_devicesupplier',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

/* dim product */
set s = now();
update 
razor_dim_product dp, 
razor_db.razor_product p,
       razor_db.razor_channel_product cp,
       razor_db.razor_channel c,
       razor_db.razor_clientdata cd,
       razor_db.razor_product_category pc,
       razor_db.razor_platform pf
set 
    dp.product_name = p.name,
    dp.product_type = pc.name,
    dp.product_active = p.active,
    dp.channel_name = c.channel_name,
    dp.channel_active = c.active,
    dp.product_key = cd.productkey,
    dp.version_name = cd.version,
    dp.platform = pf.name
where
    p.id = cp.product_id and
    cp.channel_id = c.channel_id and 
    cp.productkey = cd.productkey and 
    p.category = pc.id and 
    c.platform = pf.id and
    dp.product_id = p.id and 
    dp.channel_id = c.channel_id and 
    dp.version_name = cd.version and
    dp.userid = cp.user_id and 
    (dp.product_name <> p.name or 
    dp.product_type <> pc.name or 
    dp.product_active = p.active or 
    dp.channel_name = c.channel_name or 
    dp.channel_active = c.active or 
    dp.product_key = cd.productkey or 
    dp.version_name = cd.version or 
        dp.platform <> pf.name );
insert into razor_dim_product
           (product_id,
            product_name,
            product_type,
            product_active,
            channel_id,
            channel_name,
            channel_active,
            product_key,
            version_name,
            version_active,
            userid,
            platform)
select distinct 
p.id,
p.name,
pc.name,
p.active,
c.channel_id,
c.channel_name,
c.active,
cd.productkey,
                cd.version,
                1,
                cp.user_id,
                pf.name
from  razor_db.razor_product p inner join
       razor_db.razor_channel_product cp on p.id = cp.product_id inner join
       razor_db.razor_channel c on cp.channel_id = c.channel_id inner join
       razor_db.razor_product_category pc on p.category = pc.id inner join
       razor_db.razor_platform pf on c.platform = pf.id inner join (select distinct
       productkey,version from razor_db.razor_clientdata) cd on cp.productkey = cd.productkey  
       and not exists (select 1
                       from   razor_dim_product dp
                       where  dp.product_id = p.id and
                               dp.channel_id = c.channel_id and
                               dp.version_name = cd.version and
                               dp.userid = cp.user_id);
set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundim','razor_dim_product',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

/* dim network */
set s = now();                              
insert into razor_dim_network
           (networkname)
select distinct cd.network
from  razor_db.razor_clientdata cd
where  not exists (select 1
                       from   razor_dim_network nw
                       where  nw.networkname = cd.network);

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundim','razor_dim_network',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

/* dim activity */
set s = now();   

insert into razor_dim_activity  (activity_name,product_id)
select distinct f.activities,p.id
from   razor_db.razor_clientusinglog f,razor_db.razor_product p,razor_db.razor_channel_product cp
where  
f.appkey = cp.productkey and 
cp.product_id = p.id
and not exists (select 1
                   from   razor_dim_activity a
                   where  a.activity_name = f.activities
and a.product_id = p.id);

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundim','razor_dim_activity',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

/* dim errortitle */
set s = now();
insert into razor_dim_errortitle
           (title_name,isfix)
select distinct f.title,0
from   razor_db.razor_errorlog f
where  not exists (select *
                   from   razor_dim_errortitle ee
                   where  ee.title_name = f.title);
set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration)
     values('rundim','razor_dim_errortitle',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

/* dim event */
set s = now();
update razor_dim_event e,razor_db.razor_event_defination d
set e.eventidentifier = d.event_identifier,
e.eventname = d.event_name,
e.product_id = d.product_id,
e.active = d.active
where e.event_id = d.event_id and (e.eventidentifier <> d.event_identifier or e.eventname<>d.event_name or e.product_id <> d.product_id or e.active <> d.active);


insert into razor_dim_event       (eventidentifier,eventname,active,product_id,createtime,event_id)
select distinct event_identifier,event_name,active,product_id,create_date,f.event_id
from   razor_db.razor_event_defination f
where  not exists (select *
                   from   razor_dim_event ee
                   where  ee.eventidentifier = f.event_identifier
and ee.eventname = f.event_name
and ee.active = f.active
and ee.product_id = f.product_id
and ee.createtime = f.create_date);

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('rundim','razor_dim_event',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

insert into razor_log(op_type,op_name,op_starttime)
    values('rundim','-----finish rundim-----',now());



end$$

CREATE DEFINER=`admin`@`localhost` PROCEDURE `runfact`(IN `starttime` DATETIME, IN `endtime` DATETIME)
    NO SQL
begin
declare s datetime;
declare e datetime;

insert into razor_log(op_type,op_name,op_starttime)
    values('runfact','-----start  runfact-----',now());

set s = now();

insert into razor_fact_clientdata
           (product_sk,
            deviceos_sk,
            deviceresolution_sk,
            devicelanguage_sk,
            devicebrand_sk,
            devicesupplier_sk,
            location_sk,
            date_sk,
            hour_sk,
            deviceidentifier,
            clientdataid,
            network_sk,
            useridentifier
            )
select i.product_sk,
       b.deviceos_sk,
       d.deviceresolution_sk,
       e.devicelanguage_sk,
       c.devicebrand_sk,
       f.devicesupplier_sk,
       h.location_sk,
       g.date_sk,
       hour(a.date),
       a.deviceid,
       a.id,
       n.network_sk,
       a.useridentifier
from   razor_db.razor_clientdata a,
       razor_dim_deviceos b,
       razor_dim_devicebrand c,
       razor_dim_deviceresolution d,
       razor_dim_devicelanguage e,
       razor_dim_devicesupplier f,
       razor_dim_date g,
       razor_dim_location h,
       razor_dim_product i,
       razor_dim_network n
where 
       a.osversion = b.deviceos_name
       and a.devicename = c.devicebrand_name
       and a.resolution = d.deviceresolution_name
       and a.language = e.devicelanguage_name
       and a.service_supplier = f.mccmnc
       and date(a.date) = g.datevalue
       and a.country = h.country
       and a.region = h.region
       and a.city = h.city
       and a.productkey = i.product_key
       and i.product_active = 1 and i.channel_active = 1 and i.version_active = 1 
       and a.version = i.version_name
       and a.network = n.networkname
       and a.insertdate between starttime and endtime;

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runfact','razor_fact_clientdata',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));


set s = now();
insert into razor_fact_usinglog
           (product_sk,
            date_sk,
            activity_sk,
            session_id,
            duration,
            activities,
            starttime,
            endtime,
            uid)
select p.product_sk,
       d.date_sk,
       a.activity_sk,
       u.session_id,
       u.duration,
       u.activities,
       u.start_millis,
       end_millis,
       u.id
from   razor_db.razor_clientusinglog u,
       razor_dim_date d,
       razor_dim_product p,
       razor_dim_activity a
where  date(u.start_millis) = d.datevalue and 
       u.appkey = p.product_key 
       and p.product_id=a.product_id 
       and u.version = p.version_name 
       and u.activities = a.activity_name
       and u.insertdate between starttime and endtime;
set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runfact','razor_fact_usinglog',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

set s = now();
insert into razor_fact_errorlog
           (date_sk,
            product_sk,
            osversion_sk,
            title_sk,
            deviceidentifier,
            activity,
            time,
            title,
            stacktrace,
            isfix,
            id
            )
select d.date_sk,
       p.product_sk,
       o.deviceos_sk,
       t.title_sk,
       b.devicebrand_sk,
       e.activity,
       e.time,
       e.title,
       e.stacktrace,
       e.isfix,
       e.id
from   razor_db.razor_errorlog e,
       razor_dim_product p,
       razor_dim_date d,
       razor_dim_deviceos o,
       razor_dim_errortitle t,
       razor_dim_devicebrand b
where  e.appkey = p.product_key
       and e.version = p.version_name
       and date(e.time) = d.datevalue
       and e.os_version = o.deviceos_name
       and e.title = t.title_name
       and e.device = b.devicebrand_name
       and p.product_active = 1 and p.channel_active = 1 and p.version_active = 1
       and e.insertdate between starttime and endtime; 
set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runfact','razor_fact_errorlog',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));


set s = now();
insert into razor_fact_event
           (event_sk,
            product_sk,
            date_sk,
            deviceid,
            category,
            event,
            label,
            attachment,
            clientdate,
            number)
select e.event_sk,
       p.product_sk,
       d.date_sk,
       f.deviceid,
       f.category,
       f.event,
       f.label,
       f.attachment,
       f.clientdate,
       f.num
from   razor_db.razor_eventdata f,
       razor_dim_event e,
       razor_dim_product p,
       razor_dim_date d
where  f.event_id = e.event_id
       and e.product_id = p.product_id
       and f.version = p.version_name
       and f.productkey = p.product_key
       and p.product_active = 1 and p.channel_active = 1 and p.version_active = 1
       and date(f.clientdate) = d.datevalue
       and f.insertdate between starttime and endtime;
set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runfact','razor_fact_event',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
set s = now();

insert into razor_log(op_type,op_name,op_starttime)
    values('runfact','-----finish runfact-----',now());
    
end$$

CREATE DEFINER=`admin`@`localhost` PROCEDURE `runmonthly`(IN `begindate` DATE, IN `enddate` DATE)
    NO SQL
begin


declare s datetime;
declare e datetime;
DECLARE col VARCHAR(16); 
DECLARE months INT; 
DECLARE m INT; 

insert into razor_log(op_type,op_name,op_starttime) 
    values('runmonthly','-----start runmonthly-----',now());
    
set s = now();
-- new users for monthly reserve. for each channel, each version
INSERT INTO razor_sum_reserveusers_monthly 
            (startdate_sk, 
             enddate_sk, 
             product_id, 
             version_name, 
             channel_name, 
             usercount) 
SELECT (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = begindate)     startdate_sk, 
       (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = enddate)       enddate_sk, 
       ifnull(p.product_id,-1), 
       ifnull(p.version_name,'all'), 
       ifnull(p.channel_name,'all'),
       Count(DISTINCT f.deviceidentifier) count 
FROM   razor_fact_clientdata f, 
       razor_dim_date d, 
       razor_dim_product p 
WHERE  f.date_sk = d.date_sk 
       AND d.datevalue BETWEEN begindate AND enddate 
       AND f.product_sk = p.product_sk 
       AND p.product_active = 1 
       AND p.channel_active = 1 
       AND p.version_active = 1 
       AND f.isnew = 1 
GROUP  BY p.product_id, 
          p.version_name,
          p.channel_name with rollup
union
SELECT (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = begindate)     startdate_sk, 
       (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = enddate)       enddate_sk, 
       ifnull(p.product_id,-1), 
       ifnull(p.version_name,'all'), 
       ifnull(p.channel_name,'all'),
       Count(DISTINCT f.deviceidentifier) count 
FROM   razor_fact_clientdata f, 
       razor_dim_date d, 
       razor_dim_product p 
WHERE  f.date_sk = d.date_sk 
       AND d.datevalue BETWEEN begindate AND enddate 
       AND f.product_sk = p.product_sk 
       AND p.product_active = 1 
       AND p.channel_active = 1 
       AND p.version_active = 1 
       AND f.isnew = 1 
GROUP  BY p.product_id, 
          p.channel_name,
          p.version_name with rollup
ON DUPLICATE KEY UPDATE usercount=VALUES(usercount);

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runmonthly','razor_sum_reserveusers_monthly new users for app,version,channel dimensions',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
    
set m = 1;
while m<=8 do
  begin
    set col = concat('month',m);

    set months = -m;
    set s = now();
    
    -- 8 months for each channel, each version
    SET @sql=Concat(
        'insert into razor_sum_reserveusers_monthly(startdate_sk, enddate_sk, product_id,version_name,channel_name,',
        col,
        ') Select
        (select date_sk from razor_dim_date where datevalue = date_add(\'',begindate,'\',interval ',months,' MONTH)) startdate,
        (select date_sk from razor_dim_date where datevalue = last_day(\'',enddate,'\' + interval ',months,' MONTH)) enddate,
        ifnull(p.product_id,-1),ifnull(p.version_name,\'all\'),ifnull(p.channel_name,\'all\'),
        count(distinct f.deviceidentifier)
        from
        razor_fact_clientdata f, razor_dim_date d, razor_dim_product p where f.date_sk = d.date_sk and 
        f.product_sk = p.product_sk and d.datevalue between \'',begindate,'\' and \'',enddate,'\' and p.product_active = 1 
        and p.channel_active = 1 and p.version_active = 1 and exists
        (select 1 from razor_fact_clientdata ff, razor_dim_product pp, razor_dim_date dd 
        where ff.product_sk = pp.product_sk and ff.date_sk = dd.date_sk and pp.product_id = p.product_id and 
        dd.datevalue between date_add(\'',begindate,'\',interval ',months,' MONTH) and last_day(\'',enddate,'\' + interval ',months,' MONTH) and 
        ff.deviceidentifier = f.deviceidentifier and pp.product_active = 1 and pp.channel_active = 1 and 
        pp.version_active = 1 and ff.isnew = 1 ) group by p.product_id,p.version_name,p.channel_name with rollup
        union
        Select
        (select date_sk from razor_dim_date where datevalue = date_add(\'',begindate,'\',interval ',months,' MONTH)) startdate,
        (select date_sk from razor_dim_date where datevalue = last_day(\'',enddate,'\' + interval ',months,' MONTH)) enddate,
        ifnull(p.product_id,-1),ifnull(p.version_name,\'all\'),ifnull(p.channel_name,\'all\'),
        count(distinct f.deviceidentifier)
        from
        razor_fact_clientdata f, razor_dim_date d, razor_dim_product p where f.date_sk = d.date_sk and 
        f.product_sk = p.product_sk and d.datevalue between \'',begindate,'\' and \'',enddate,'\' and p.product_active = 1 
        and p.channel_active = 1 and p.version_active = 1 and exists
        (select 1 from razor_fact_clientdata ff, razor_dim_product pp, razor_dim_date dd 
        where ff.product_sk = pp.product_sk and ff.date_sk = dd.date_sk and pp.product_id = p.product_id and 
        dd.datevalue between date_add(\'',begindate,'\',interval ',months,' MONTH) and last_day(\'',enddate,'\' + interval ',months,' MONTH) and 
        ff.deviceidentifier = f.deviceidentifier and pp.product_active = 1 and pp.channel_active = 1 and 
        pp.version_active = 1 and ff.isnew = 1 ) group by p.product_id,p.channel_name,p.version_name with rollup
        on duplicate key update ',
        col,
        '= values(',
        col,
        ');');
    
    PREPARE sl FROM @sql;
    EXECUTE sl;
    DEALLOCATE PREPARE sl;
    
    set e = now();
    insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runmonthly',concat('razor_sum_reserveusers_monthly MONTH ',-m,' reserve users for app,channel,version dimensions'),s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
    set s = now();
    

    
    set m = m + 1; 
  end;
end while;

set s = now();
INSERT INTO razor_sum_basic_activeusers 
            (product_id, 
             month_activeuser, 
             month_percent) 
SELECT p.product_id, 
       Count(DISTINCT f.deviceidentifier) activeusers, 
       Count(DISTINCT f.deviceidentifier) / (SELECT 
       Count(DISTINCT ff.deviceidentifier) 
                                             FROM   razor_fact_clientdata ff, 
                                                    razor_dim_date dd, 
                                                    razor_dim_product pp 
                                             WHERE  dd.datevalue <= enddate 
                                                    AND 
                                            pp.product_id = p.product_id 
                                                    AND pp.product_active = 1 
                                                    AND pp.channel_active = 1 
                                                    AND pp.version_active = 1 
                                                    AND 
                                            ff.product_sk = pp.product_sk 
                                                    AND ff.date_sk = dd.date_sk) 
                                          percent 
FROM   razor_fact_clientdata f, 
       razor_dim_date d, 
       razor_dim_product p 
WHERE  d.datevalue BETWEEN begindate AND enddate 
       AND p.product_active = 1 
       AND p.channel_active = 1 
       AND p.version_active = 1 
       AND f.product_sk = p.product_sk 
       AND f.date_sk = d.date_sk 
GROUP  BY p.product_id 
ON DUPLICATE KEY UPDATE month_activeuser=VALUES(month_activeuser),month_percent=VALUES(month_percent);

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runmonthly','razor_sum_basic_activeusers active users and percent',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
    
    
set s = now();
INSERT INTO razor_sum_basic_channel_activeusers 
            (date_sk, 
             product_id, 
             channel_id, 
             activeuser, 
             percent, 
             flag) 
SELECT (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = begindate)     startdate, 
       p.product_id, 
       p.channel_id, 
       Count(DISTINCT f.deviceidentifier) activeusers, 
       Count(DISTINCT f.deviceidentifier) / (SELECT 
       Count(DISTINCT ff.deviceidentifier) 
                                             FROM   razor_fact_clientdata ff, 
                                                    razor_dim_date dd, 
                                                    razor_dim_product pp 
                                             WHERE  dd.datevalue <= enddate 
                                                    AND 
                                            pp.product_id = p.product_id 
                                                    AND 
                                            pp.channel_id = p.channel_id 
                                                    AND pp.product_active = 1 
                                                    AND pp.channel_active = 1 
                                                    AND pp.version_active = 1 
                                                    AND 
                                            ff.product_sk = pp.product_sk 
                                                    AND 
       ff.date_sk = dd.date_sk), 
       1 
FROM   razor_fact_clientdata f, 
       razor_dim_date d, 
       razor_dim_product p 
WHERE  d.datevalue BETWEEN begindate AND enddate 
       AND p.product_active = 1 
       AND p.channel_active = 1 
       AND p.version_active = 1 
       AND f.product_sk = p.product_sk 
       AND f.date_sk = d.date_sk 
GROUP  BY p.product_id, 
          p.channel_id 
ON DUPLICATE KEY UPDATE activeuser = VALUES(activeuser),percent=VALUES(percent);

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runmonthly','razor_sum_basic_channel_activeusers channel activeusers and percent',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

insert into razor_log(op_type,op_name,op_starttime) 
    values('runmonthly','-----finish runmonthly-----',now());

end$$

CREATE DEFINER=`admin`@`localhost` PROCEDURE `runsum`(IN `today` DATE)
    NO SQL
begin
declare s datetime;
declare e datetime;

insert into razor_log(op_type,op_name,op_starttime) 
    values('runsum','-----start runsum-----',now());
    
-- update fact_clientdata  
set s = now();
update  razor_fact_clientdata a,
        razor_fact_clientdata b,
        razor_dim_date c,
        razor_dim_product d,
        razor_dim_product f 
set     a.isnew=0 
where   ((a.date_sk>b.date_sk) or (a.date_sk=b.date_sk and a.dataid>b.dataid)) 
and     a.isnew=1 
and     a.date_sk=c.date_sk 
and     c.datevalue=today
and     a.product_sk=d.product_sk 
and     b.product_sk=f.product_sk 
and     a.deviceidentifier=b.deviceidentifier 
and     d.product_id=f.product_id;

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_fact_clientdata update',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

set s = now();

update razor_fact_clientdata a,
       razor_fact_clientdata b,
       razor_dim_date c,
       razor_dim_product d,
       razor_dim_product f 
set    a.isnew_channel=0 
where  ((a.date_sk>b.date_sk) or (a.date_sk=b.date_sk and a.dataid>b.dataid))
       and a.isnew_channel=1 
       and a.date_sk=c.date_sk 
       and c.datevalue=today 
       and a.product_sk=d.product_sk 
       and b.product_sk=f.product_sk 
       and a.deviceidentifier=b.deviceidentifier 
       and d.product_id=f.product_id 
       and d.channel_id=f.channel_id;

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_fact_clientdata update',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

-- sum usinglog for each sessions
set s = now();
insert into razor_fact_usinglog_daily
           (product_sk,
            date_sk,
            session_id,
            duration)
select  f.product_sk,
         d.date_sk,
         f.session_id,
         sum(f.duration)
from    razor_fact_usinglog f,
         razor_dim_date d
where   
         d.datevalue = today and f.date_sk = d.date_sk
group by f.product_sk,d.date_sk,f.session_id on duplicate key update duration = values(duration);

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_fact_usinglog_daily',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

-- sum_basic_product 

set s = now();
insert into razor_sum_basic_product(product_id,date_sk,sessions) 
select p.product_id, d.date_sk,count(f.deviceidentifier) 
from razor_fact_clientdata f,
     razor_dim_date d,
     razor_dim_product p
where d.datevalue = today 
      and f.date_sk = d.date_sk 
      and f.product_sk=p.product_sk
group by p.product_id on duplicate key update sessions = values(sessions);

insert into razor_sum_basic_product(product_id,date_sk,startusers) 
select p.product_id, d.date_sk,count(distinct f.deviceidentifier) 
from razor_fact_clientdata f,
     razor_dim_date d,
     razor_dim_product p 
where d.datevalue = today 
      and f.date_sk = d.date_sk 
      and p.product_sk=f.product_sk 
group by p.product_id on duplicate key update startusers = values(startusers);

insert into razor_sum_basic_product(product_id,date_sk,newusers) 
select p.product_id, f.date_sk,sum(f.isnew) 
from razor_fact_clientdata f, 
     razor_dim_date d, 
     razor_dim_product p 
where d.datevalue = today 
      and f.date_sk = d.date_sk 
      and p.product_sk = f.product_sk 
      and p.product_active = 1 
      and p.channel_active = 1 
      and p.version_active = 1 
group by p.product_id,f.date_sk on duplicate key update newusers = values(newusers);

insert into razor_sum_basic_product(product_id,date_sk,upgradeusers) 
select p.product_id, d.date_sk,
count(distinct f.deviceidentifier) 
from razor_fact_clientdata f, 
     razor_dim_date d, 
     razor_dim_product p 
where d.datevalue = today 
      and f.date_sk = d.date_sk 
      and p.product_sk = f.product_sk 
      and p.product_active = 1
      and p.channel_active = 1 
      and p.version_active = 1 
      and exists 
(select 1 
from razor_fact_clientdata ff, 
     razor_dim_date dd, razor_dim_product pp 
where dd.datevalue < today 
      and ff.date_sk = dd.date_sk 
      and pp.product_sk = ff.product_sk
      and pp.product_id = p.product_id 
      and pp.product_active = 1 
      and pp.channel_active = 1 
      and pp.version_active = 1 
      and f.deviceidentifier = ff.deviceidentifier 
      and STRCMP( pp.version_name, p.version_name ) < 0) 
group by p.product_id,d.date_sk on duplicate key update upgradeusers = values(upgradeusers);

insert into razor_sum_basic_product(product_id,date_sk,allusers) 
select f.product_id, 
(
 select date_sk 
 from razor_dim_date 
where datevalue=today) date_sk,
sum(f.newusers) 
from razor_sum_basic_product f,
     razor_dim_date d 
where d.date_sk=f.date_sk 
      and d.datevalue<=today 
group by f.product_id on duplicate key update allusers = values(allusers);

insert into razor_sum_basic_product(product_id,date_sk,allsessions) 
select f.product_id,(select date_sk from razor_dim_date where datevalue=today) date_sk,sum(f.sessions) 
from razor_sum_basic_product f,
     razor_dim_date d 
where d.datevalue<=today 
      and d.date_sk=f.date_sk 
group by f.product_id on duplicate key update allsessions = values(allsessions);

insert into razor_sum_basic_product(product_id,date_sk,usingtime)
select p.product_id,f.date_sk,sum(duration) 
from razor_fact_usinglog_daily f,
     razor_dim_product p,
     razor_dim_date d 
where f.date_sk = d.date_sk 
      and d.datevalue = today 
      and f.product_sk=p.product_sk 
group by p.product_id on duplicate key update usingtime = values(usingtime);

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_sum_basic_product',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

-- sum_basic_channel 
set s = now();
insert into razor_sum_basic_channel(product_id,channel_id,date_sk,sessions) 
select p.product_id,p.channel_id,d.date_sk,count(f.deviceidentifier) 
from razor_fact_clientdata f, 
     razor_dim_date d,
     razor_dim_product p
where d.datevalue = today 
      and f.date_sk = d.date_sk 
      and f.product_sk=p.product_sk
group by p.product_id,p.channel_id on duplicate key update sessions = values(sessions);

insert into razor_sum_basic_channel(product_id,channel_id,date_sk,startusers) 
select p.product_id,p.channel_id, d.date_sk,count(distinct f.deviceidentifier) 
from razor_fact_clientdata f,
     razor_dim_date d,
     razor_dim_product p 
where d.datevalue = today 
      and f.date_sk = d.date_sk 
      and p.product_sk=f.product_sk 
group by p.product_id,p.channel_id on duplicate key update startusers = values(startusers);

insert into razor_sum_basic_channel(product_id,channel_id,date_sk,newusers) 
select p.product_id,p.channel_id,f.date_sk,sum(f.isnew_channel) 
from razor_fact_clientdata f,
     razor_dim_date d, 
     razor_dim_product p 
where d.datevalue = today 
      and f.date_sk = d.date_sk 
      and p.product_sk = f.product_sk 
      and p.product_active = 1 
      and p.channel_active = 1 
      and p.version_active = 1 
group by p.product_id,p.channel_id,f.date_sk on duplicate key update newusers = values(newusers);

insert into razor_sum_basic_channel(product_id,channel_id,date_sk,upgradeusers) 
select p.product_id,p.channel_id,d.date_sk,
count(distinct f.deviceidentifier) 
from razor_fact_clientdata f,
     razor_dim_date d, 
     razor_dim_product p 
where d.datevalue = today 
      and f.date_sk = d.date_sk 
      and p.product_sk = f.product_sk  
      and p.product_active = 1 
      and p.channel_active = 1 
     and p.version_active = 1 
and exists 
(select 1 
from razor_fact_clientdata ff,
     razor_dim_date dd,
     razor_dim_product pp 
where dd.datevalue < today 
      and ff.date_sk = dd.date_sk 
      and pp.product_sk = ff.product_sk 
      and pp.product_id = p.product_id 
      and pp.channel_id=p.channel_id 
      and pp.product_active = 1 
      and pp.channel_active = 1 
      and pp.version_active = 1 
      and f.deviceidentifier = ff.deviceidentifier 
      and STRCMP( pp.version_name, p.version_name ) < 0) 
 group by p.product_id,p.channel_id,d.date_sk on duplicate key update upgradeusers = values(upgradeusers);

insert into razor_sum_basic_channel(product_id,channel_id,date_sk,allusers) 
select f.product_id,f.channel_id,
(select date_sk 
  from razor_dim_date 
  where datevalue=today) date_sk,
sum(f.newusers)
from razor_sum_basic_channel f,
     razor_dim_date d
where d.date_sk=f.date_sk 
      and d.datevalue<=today 
group by f.product_id,f.channel_id on duplicate key update allusers = values(allusers); 

insert into razor_sum_basic_channel(product_id,channel_id,date_sk,allsessions) 
select f.product_id,f.channel_id,(select date_sk from razor_dim_date where datevalue=today) date_sk,
sum(f.sessions) 
from razor_sum_basic_channel f,
     razor_dim_date d 
where d.datevalue<=today 
      and d.date_sk=f.date_sk 
group by f.product_id,f.channel_id on duplicate key update allsessions = values(allsessions);

insert into razor_sum_basic_channel(product_id,channel_id,date_sk,usingtime)
select p.product_id,p.channel_id,f.date_sk,sum(duration) 
from razor_fact_usinglog_daily f,
     razor_dim_product p,
     razor_dim_date d where f.date_sk = d.date_sk 
and d.datevalue = today and f.product_sk=p.product_sk 
group by p.product_id,p.channel_id on duplicate key update usingtime = values(usingtime);

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_sum_basic_channel',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
  
    
-- sum_basic_product_version 

set s = now();
insert into razor_sum_basic_product_version(product_id,date_sk,version_name,sessions) 
select p.product_id, d.date_sk,p.version_name,count(f.deviceidentifier) 
from razor_fact_clientdata f,
     razor_dim_date d,
     razor_dim_product p
where d.datevalue = today 
      and f.date_sk = d.date_sk 
      and f.product_sk=p.product_sk
group by p.product_id,p.version_name on duplicate key update sessions = values(sessions);

insert into razor_sum_basic_product_version(product_id,date_sk,version_name,startusers) 
select p.product_id, d.date_sk,p.version_name,count(distinct f.deviceidentifier) 
from razor_fact_clientdata f,
     razor_dim_date d,
     razor_dim_product p 
where d.datevalue = today 
      and f.date_sk = d.date_sk
      and p.product_sk=f.product_sk 
group by p.product_id,p.version_name on duplicate key update startusers = values(startusers);

insert into razor_sum_basic_product_version(product_id,date_sk,version_name,newusers) 
select p.product_id, f.date_sk,p.version_name,sum(f.isnew) 
from razor_fact_clientdata f,
     razor_dim_date d, 
     razor_dim_product p 
where d.datevalue = today 
      and f.date_sk = d.date_sk  
      and p.product_sk = f.product_sk 
      and p.product_active = 1 
      and p.channel_active = 1 
      and p.version_active = 1 
      group by p.product_id,p.version_name,f.date_sk  
on duplicate key update newusers = values(newusers);

insert into razor_sum_basic_product_version(product_id,date_sk,version_name,upgradeusers) 
select p.product_id, d.date_sk,p.version_name,
count(distinct f.deviceidentifier)
from razor_fact_clientdata f, 
     razor_dim_date d,  
     razor_dim_product p 
where d.datevalue = today 
      and f.date_sk = d.date_sk 
      and p.product_sk = f.product_sk 
      and p.product_active = 1 
      and p.channel_active = 1 
      and p.version_active = 1 
      and exists 
(select 1 
from razor_fact_clientdata ff, 
     razor_dim_date dd,
     razor_dim_product pp 
where dd.datevalue < today 
      and ff.date_sk = dd.date_sk 
      and pp.product_sk = ff.product_sk
      and pp.product_id = p.product_id 
      and pp.product_active = 1 
      and pp.channel_active = 1 
      and pp.version_active = 1 
      and f.deviceidentifier = ff.deviceidentifier 
      and STRCMP( pp.version_name, p.version_name ) < 0) 
 group by   p.product_id,p.version_name,d.date_sk on duplicate key update upgradeusers = values(upgradeusers);

insert into razor_sum_basic_product_version(product_id,date_sk,version_name,allusers) 
select f.product_id, 
(select date_sk 
 from razor_dim_date 
where datevalue=today) date_sk,
f.version_name,
sum(f.newusers) 
from razor_sum_basic_product_version f,
     razor_dim_date d
where d.date_sk=f.date_sk 
      and d.datevalue<=today
group by f.product_id,f.version_name on duplicate key update allusers = values(allusers);

insert into razor_sum_basic_product_version(product_id,date_sk,version_name,allsessions) 
select f.product_id,(select date_sk from razor_dim_date where datevalue=today) date_sk,f.version_name,sum(f.sessions) 
from razor_sum_basic_product_version f,
     razor_dim_date d 
where d.datevalue<=today 
      and d.date_sk=f.date_sk 
group by f.product_id,f.version_name on duplicate key update allsessions = values(allsessions);

insert into razor_sum_basic_product_version(product_id,date_sk,version_name,usingtime)
select p.product_id,f.date_sk,p.version_name,sum(duration) 
from razor_fact_usinglog_daily f,
     razor_dim_product p,
     razor_dim_date d 
where f.date_sk = d.date_sk 
      and d.datevalue = today 
      and f.product_sk=p.product_sk 
group by p.product_id,p.version_name on duplicate key update usingtime = values(usingtime);

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
values('runsum','razor_sum_basic_product_version',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));  
  

set s = now();
-- update segment_sk column

update razor_fact_usinglog_daily f,razor_dim_segment_usinglog s,razor_dim_date d
set    f.segment_sk = s.segment_sk
where  f.duration >= s.startvalue
       and f.duration < s.endvalue
       and f.date_sk = d.date_sk
       and d.datevalue = today;
set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_fact_usinglog_daily update',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

set s = now();
-- sum_basic_byhour --
Insert into razor_sum_basic_byhour(product_sk,date_sk,hour_sk,
sessions) 
Select f.product_sk, f.date_sk,f.hour_sk,
count(f.deviceidentifier) from razor_fact_clientdata f, razor_dim_date d
where d.datevalue = today and f.date_sk = d.date_sk
group by f.product_sk,f.date_sk,f.hour_sk on duplicate 
key update sessions = values(sessions);

Insert into razor_sum_basic_byhour(product_sk,date_sk,hour_sk,
startusers) 
Select f.product_sk, f.date_sk,f.hour_sk,
count(distinct f.deviceidentifier) from 
razor_fact_clientdata f, razor_dim_date d where d.datevalue = today  
and f.date_sk = d.date_sk group by f.product_sk,d.date_sk,
f.hour_sk on duplicate key update startusers = values(startusers);

Insert into razor_sum_basic_byhour(product_sk,date_sk,hour_sk,newusers) 
Select f.product_sk, f.date_sk,f.hour_sk,count(distinct f.deviceidentifier) from razor_fact_clientdata f, razor_dim_date d, razor_dim_product p where d.datevalue = today and f.date_sk = d.date_sk and p.product_sk = f.product_sk and p.product_active = 1 and p.channel_active = 1 and p.version_active = 1 and not exists (select 1 from razor_fact_clientdata ff, razor_dim_date dd, razor_dim_product pp where dd.datevalue < today and ff.date_sk = dd.date_sk and pp.product_sk = ff.product_sk and p.product_id = pp.product_id and pp.product_active = 1 and pp.channel_active = 1 and pp.version_active = 1 and f.deviceidentifier = ff.deviceidentifier) group by f.product_sk,f.date_sk,f.hour_sk on duplicate key update newusers = values(newusers);
set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_sum_basic_byhour',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));


set s = now();
-- sum_usinglog_activity --
insert into razor_sum_usinglog_activity(date_sk,product_sk,activity_sk,accesscount,totaltime)
select d.date_sk,p.product_sk,a.activity_sk, count(*), sum(duration)
from        razor_fact_usinglog f,         razor_dim_product p,   razor_dim_date d, razor_dim_activity a
where    f.date_sk = d.date_sk and f.activity_sk = a.activity_sk
         and d.datevalue =today
         and f.product_sk = p.product_sk
         and p.product_active = 1 and p.channel_active = 1 and p.version_active = 1 
group by d.date_sk,p.product_sk,a.activity_sk
on duplicate key update accesscount = values(accesscount),totaltime = values(totaltime);

insert into razor_sum_usinglog_activity(date_sk,product_sk,activity_sk,exitcount)
select tt.date_sk,tt.product_sk, tt.activity_sk,count(*)
from
(select * from(
select   d.date_sk,session_id,p.product_sk,f.activity_sk,endtime
                    from     razor_fact_usinglog f,
                             razor_dim_product p,
                             razor_dim_date d
                    where    f.date_sk = d.date_sk
                             and d.datevalue = today
                             and f.product_sk = p.product_sk
                    order by session_id,
                             endtime desc) t group by t.session_id) tt
group by tt.date_sk,tt.product_sk,tt.activity_sk
order by tt. date_sk,tt.product_sk,tt.activity_sk on duplicate key update
exitcount = values(exitcount);
set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_sum_usinglog_activity',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));


set s = now();
insert into razor_fact_launch_daily
           (product_sk,
            date_sk,
            segment_sk,
            accesscount) 
select rightf.product_sk,
       rightf.date_sk,
       rightf.segment_sk,
       ifnull(ffff.num,0)
from (select  fff.product_sk,
         fff.date_sk,
         fff.segment_sk,
         count(fff.segment_sk) num
         from (select fs.datevalue,
                 dd.date_sk,
                 fs.product_sk,
                 fs.deviceidentifier,
                 fs.times,
                 ss.segment_sk
                 from (select   d.datevalue,
                           p.product_sk,
                           deviceidentifier,
                           count(* ) times
                           from  razor_fact_clientdata f,
                           razor_dim_date d,
                           razor_dim_product p
                           where d.datevalue = today
                           and f.date_sk = d.date_sk
                           and p.product_sk = f.product_sk
                  group by d.datevalue,p.product_sk,deviceidentifier) fs,
                 razor_dim_segment_launch ss,
                 razor_dim_date dd
          where  fs.times between ss.startvalue and ss.endvalue
                 and dd.datevalue = fs.datevalue) fff
group by fff.date_sk,fff.segment_sk,fff.product_sk
order by fff.date_sk,
         fff.segment_sk,
         fff.product_sk) ffff right join (select fff.date_sk,fff.product_sk,sss.segment_sk
         from (select distinct d.date_sk,p.product_sk 
         from razor_fact_clientdata f,razor_dim_date d,razor_dim_product p 
         where d.datevalue=today and f.date_sk=d.date_sk and p.product_sk = f.product_sk) fff cross join
         razor_dim_segment_launch sss) rightf on ffff.date_sk=rightf.date_sk and
         ffff.product_sk=rightf.product_sk and ffff.segment_sk=rightf.segment_sk
          on duplicate key update accesscount = values(accesscount);
set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_fact_launch_daily',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));


set s = now();

insert into razor_sum_location(product_id,date_sk,location_sk,sessions)
select p.product_id,d.date_sk,l.location_sk, count(*)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_location l
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.location_sk = l.location_sk 
         and f.product_sk = p.product_sk
group by p.product_id,d.date_sk,l.location_sk
on duplicate key update sessions = values(sessions);


insert into razor_sum_location(product_id,date_sk,location_sk,newusers)
select p.product_id,d.date_sk,l.location_sk, count(distinct f.deviceidentifier)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_location l
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.location_sk = l.location_sk 
         and f.product_sk = p.product_sk
         and f.isnew = 1
group by p.product_id,d.date_sk,l.location_sk
on duplicate key update newusers = values(newusers);

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_sum_location',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));



set s = now();

insert into razor_sum_devicebrand(product_id,date_sk,devicebrand_sk,sessions)
select p.product_id,d.date_sk,b.devicebrand_sk, count(*)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_devicebrand b
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.devicebrand_sk = b.devicebrand_sk 
         and f.product_sk = p.product_sk
group by p.product_id,d.date_sk,b.devicebrand_sk
on duplicate key update sessions = values(sessions);


insert into razor_sum_devicebrand(product_id,date_sk,devicebrand_sk,newusers)
select p.product_id,d.date_sk,b.devicebrand_sk, count(distinct f.deviceidentifier)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_devicebrand b
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.devicebrand_sk = b.devicebrand_sk 
         and f.product_sk = p.product_sk
         and f.isnew = 1
group by p.product_id,d.date_sk,b.devicebrand_sk
on duplicate key update newusers = values(newusers);

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_sum_devicebrand',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
    

set s = now();

insert into razor_sum_deviceos(product_id,date_sk,deviceos_sk,sessions)
select p.product_id,d.date_sk,o.deviceos_sk, count(*)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_deviceos o
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.deviceos_sk = o.deviceos_sk 
         and f.product_sk = p.product_sk
group by p.product_id,d.date_sk,o.deviceos_sk
on duplicate key update sessions = values(sessions);


insert into razor_sum_deviceos(product_id,date_sk,deviceos_sk,newusers)
select p.product_id,d.date_sk,o.deviceos_sk, count(distinct f.deviceidentifier)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_deviceos o
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.deviceos_sk = o.deviceos_sk 
         and f.product_sk = p.product_sk
         and f.isnew = 1
group by p.product_id,d.date_sk,o.deviceos_sk
on duplicate key update newusers = values(newusers);

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_sum_deviceos',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
    

set s = now();

insert into razor_sum_deviceresolution(product_id,date_sk,deviceresolution_sk,sessions)
select p.product_id,d.date_sk,r.deviceresolution_sk, count(*)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_deviceresolution r
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.deviceresolution_sk = r.deviceresolution_sk 
         and f.product_sk = p.product_sk
group by p.product_id,d.date_sk,r.deviceresolution_sk
on duplicate key update sessions = values(sessions);


insert into razor_sum_deviceresolution(product_id,date_sk,deviceresolution_sk,newusers)
select p.product_id,d.date_sk,r.deviceresolution_sk, count(distinct f.deviceidentifier)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_deviceresolution r
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.deviceresolution_sk = r.deviceresolution_sk 
         and f.product_sk = p.product_sk
         and f.isnew = 1
group by p.product_id,d.date_sk,r.deviceresolution_sk
on duplicate key update newusers = values(newusers);

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_sum_deviceresolution',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));


set s = now();

insert into razor_sum_devicesupplier(product_id,date_sk,devicesupplier_sk,sessions)
select p.product_id,d.date_sk,s.devicesupplier_sk, count(*)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_devicesupplier s
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.devicesupplier_sk = s.devicesupplier_sk 
         and f.product_sk = p.product_sk
group by p.product_id,d.date_sk,s.devicesupplier_sk
on duplicate key update sessions = values(sessions);


insert into razor_sum_devicesupplier(product_id,date_sk,devicesupplier_sk,newusers)
select p.product_id,d.date_sk,s.devicesupplier_sk, count(distinct f.deviceidentifier)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_devicesupplier s
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.devicesupplier_sk = s.devicesupplier_sk 
         and f.product_sk = p.product_sk
         and f.isnew = 1
group by p.product_id,d.date_sk,s.devicesupplier_sk
on duplicate key update newusers = values(newusers);

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_sum_devicesupplier',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));


set s = now();

insert into razor_sum_devicenetwork(product_id,date_sk,devicenetwork_sk,sessions)
select p.product_id,d.date_sk,n.network_sk, count(*)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_network n
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.network_sk = n.network_sk 
         and f.product_sk = p.product_sk
group by p.product_id,d.date_sk,n.network_sk
on duplicate key update sessions = values(sessions);


insert into razor_sum_devicenetwork(product_id,date_sk,devicenetwork_sk,newusers)
select p.product_id,d.date_sk,n.network_sk, count(distinct f.deviceidentifier)
from     razor_fact_clientdata f,
         razor_dim_product p,
         razor_dim_date d,
         razor_dim_network n
where    f.date_sk = d.date_sk
         and d.datevalue = today 
         and f.network_sk = n.network_sk 
         and f.product_sk = p.product_sk
         and f.isnew = 1
group by p.product_id,d.date_sk,n.network_sk
on duplicate key update newusers = values(newusers);

set e = now();
insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_sum_devicenetwork',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));


set s = now();
insert into razor_sum_event(product_sk,date_sk,event_sk, total)
SELECT product_sk,f.date_sk,event_sk,sum(number) FROM `razor_fact_event` f,
         razor_dim_date d
where f.date_sk = d.date_sk  and d.datevalue = today 
group by product_sk,f.date_sk,event_sk
on duplicate key update total=values(total);

insert into razor_log(op_type,op_name,op_date,affected_rows,duration) 
    values('runsum','razor_sum_event',e,row_count(),TIMESTAMPDIFF(SECOND,s,e));


insert into razor_log(op_type,op_name,op_starttime) 
    values('runsum','-----finish runsum-----',now());
    
end$$

CREATE DEFINER=`admin`@`localhost` PROCEDURE `runweekly`(IN `begindate` DATE, IN `enddate` DATE)
    NO SQL
begin

DECLARE s datetime; 
DECLARE e datetime; 
DECLARE col VARCHAR(16); 
DECLARE days INT; 
DECLARE w INT; 

insert into razor_log(op_type,op_name,op_starttime) 
    values('runweekly','-----start runweekly-----',now());
    
set s = now();

-- generate the count of new users for last week

-- for channels, versions
INSERT INTO razor_sum_reserveusers_weekly 
            (startdate_sk, 
             enddate_sk, 
             product_id, 
             version_name, 
             channel_name, 
             usercount) 
SELECT (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = begindate)     startdate_sk, 
       (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = enddate)       enddate_sk, 
       ifnull(p.product_id,-1), 
       ifnull(p.version_name,'all'),
       ifnull(p.channel_name,'all'), 
       Count(DISTINCT f.deviceidentifier) count 
FROM   razor_fact_clientdata f, 
       razor_dim_date d, 
       razor_dim_product p 
WHERE  f.date_sk = d.date_sk 
       AND d.datevalue BETWEEN begindate AND enddate 
       AND f.product_sk = p.product_sk 
       AND p.product_active = 1 
       AND p.channel_active = 1 
       AND p.version_active = 1 
       AND f.isnew = 1 
GROUP  BY p.product_id, 
          p.version_name,
          p.channel_name with rollup
union
SELECT (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = begindate)     startdate_sk, 
       (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = enddate)       enddate_sk, 
       ifnull(p.product_id,-1), 
       ifnull(p.version_name,'all'),
       ifnull(p.channel_name,'all'), 
       Count(DISTINCT f.deviceidentifier) count 
FROM   razor_fact_clientdata f, 
       razor_dim_date d, 
       razor_dim_product p 
WHERE  f.date_sk = d.date_sk 
       AND d.datevalue BETWEEN begindate AND enddate 
       AND f.product_sk = p.product_sk 
       AND p.product_active = 1 
       AND p.channel_active = 1 
       AND p.version_active = 1 
       AND f.isnew = 1 
GROUP  BY p.product_id, 
          p.channel_name,
          p.version_name with rollup
ON DUPLICATE KEY UPDATE usercount=VALUES(usercount);


set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runweekly','razor_sum_reserveusers_weekly new users for app,version,channel dimensions',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));


set w = 1;
while w<=8 do
  begin
    set col = concat('week',w);

    set days = -w*7;
    
    set s = now();
    
    -- 8 weeks for app,channel, version
    SET @sql=concat(
        'insert into razor_sum_reserveusers_weekly(startdate_sk, enddate_sk, product_id, version_name,channel_name,',
        col,
        ')
        Select 
        (select date_sk from razor_dim_date where datevalue= date_add(\'',begindate,'\',interval ',days,' DAY)) startdate,
        (select date_sk from razor_dim_date where datevalue= date_add(\'',enddate,'\',interval ',days,' DAY)) enddate,
        ifnull(p.product_id,-1),ifnull(p.version_name,\'all\'),ifnull(p.channel_name,\'all\'),
        count(distinct f.deviceidentifier)
        from
        razor_fact_clientdata f, razor_dim_date d, razor_dim_product p where f.date_sk = d.date_sk 
        and f.product_sk = p.product_sk and d.datevalue between \'',begindate,'\' and \'',enddate,'\' and p.product_active=1 
        and p.channel_active=1 and p.version_active=1 and exists 
         (select 1 from razor_fact_clientdata ff, razor_dim_product pp, razor_dim_date dd where ff.product_sk = pp.product_sk 
         and ff.date_sk = dd.date_sk and pp.product_id = p.product_id and dd.datevalue between 
         date_add(\'',begindate,'\',interval ',days,' DAY) and 
         date_add(\'',enddate,'\',interval ',days,' DAY) and ff.deviceidentifier = f.deviceidentifier and pp.product_active=1 
         and pp.channel_active=1 and pp.version_active=1 and ff.isnew=1) group by p.product_id,p.version_name,p.channel_name with rollup
         union
         Select 
        (select date_sk from razor_dim_date where datevalue= date_add(\'',begindate,'\',interval ',days,' DAY)) startdate,
        (select date_sk from razor_dim_date where datevalue= date_add(\'',enddate,'\',interval ',days,' DAY)) enddate,
        ifnull(p.product_id,-1),ifnull(p.version_name,\'all\'),ifnull(p.channel_name,\'all\'),
        count(distinct f.deviceidentifier)
        from
        razor_fact_clientdata f, razor_dim_date d, razor_dim_product p where f.date_sk = d.date_sk 
        and f.product_sk = p.product_sk and d.datevalue between \'',begindate,'\' and \'',enddate,'\' and p.product_active=1 
        and p.channel_active=1 and p.version_active=1 and exists 
         (select 1 from razor_fact_clientdata ff, razor_dim_product pp, razor_dim_date dd where ff.product_sk = pp.product_sk 
         and ff.date_sk = dd.date_sk and pp.product_id = p.product_id and dd.datevalue between 
         date_add(\'',begindate,'\',interval ',days,' DAY) and 
         date_add(\'',enddate,'\',interval ',days,' DAY) and ff.deviceidentifier = f.deviceidentifier and pp.product_active=1 
         and pp.channel_active=1 and pp.version_active=1 and ff.isnew=1) group by p.product_id,p.channel_name,p.version_name with rollup
        on duplicate key update ',col,'=values(',col,');');
        
    
    PREPARE sl FROM @sql;
    EXECUTE sl;
    DEALLOCATE PREPARE sl;
    
    set e = now();
    insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runweekly',concat('razor_sum_reserveusers_weekly WEEK ',-w,' reserve users for app,channel,version dimensions'),s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
    
    set w = w + 1; 
  end;
end while;

set s = now();
INSERT INTO razor_sum_basic_activeusers 
            (product_id, 
             week_activeuser, 
             week_percent) 
SELECT p.product_id, 
       Count(DISTINCT f.deviceidentifier) activeusers, 
       Count(DISTINCT f.deviceidentifier) / (SELECT 
       Count(DISTINCT ff.deviceidentifier) 
                                             FROM   razor_fact_clientdata ff, 
                                                    razor_dim_date dd, 
                                                    razor_dim_product pp 
                                             WHERE  dd.datevalue <= enddate 
                                                    AND 
                                            p.product_id = pp.product_id 
                                                    AND pp.product_active = 1 
                                                    AND pp.channel_active = 1 
                                                    AND pp.version_active = 1 
                                                    AND 
                                            ff.product_sk = pp.product_sk 
                                                    AND ff.date_sk = dd.date_sk) 
                                          percent 
FROM   razor_fact_clientdata f, 
       razor_dim_date d, 
       razor_dim_product p 
WHERE  d.datevalue BETWEEN begindate AND enddate 
       AND p.product_active = 1 
       AND p.channel_active = 1 
       AND p.version_active = 1 
       AND f.product_sk = p.product_sk 
       AND f.date_sk = d.date_sk 
GROUP  BY p.product_id 
ON DUPLICATE KEY UPDATE week_activeuser = VALUES(week_activeuser),week_percent = VALUES(week_percent);

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runweekly','razor_sum_basic_activeusers week activeuser and percent',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));
    
set s = now();
INSERT INTO razor_sum_basic_channel_activeusers 
            (date_sk, 
             product_id, 
             channel_id, 
             activeuser, 
             percent, 
             flag) 
SELECT (SELECT date_sk 
        FROM   razor_dim_date 
        WHERE  datevalue = begindate)     startdate, 
       p.product_id, 
       p.channel_id, 
       Count(DISTINCT f.deviceidentifier) activeusers, 
       Count(DISTINCT f.deviceidentifier) / (SELECT 
       Count(DISTINCT ff.deviceidentifier) 
                                             FROM   razor_fact_clientdata ff, 
                                                    razor_dim_date dd, 
                                                    razor_dim_product pp 
                                             WHERE  dd.datevalue <= enddate 
                                                    AND 
                                            pp.product_id = p.product_id 
                                                    AND 
                                            pp.channel_id = p.channel_id 
                                                    AND pp.product_active = 1 
                                                    AND pp.channel_active = 1 
                                                    AND pp.version_active = 1 
                                                    AND 
                                            ff.product_sk = pp.product_sk 
                                                    AND ff.date_sk = dd.date_sk) 
       , 
       0 
FROM   razor_fact_clientdata f, 
       razor_dim_date d, 
       razor_dim_product p 
WHERE  d.datevalue BETWEEN begindate AND enddate 
       AND p.product_active = 1 
       AND p.channel_active = 1 
       AND p.version_active = 1 
       AND f.product_sk = p.product_sk 
       AND f.date_sk = d.date_sk 
GROUP  BY p.product_id, 
          p.channel_id 
ON DUPLICATE KEY UPDATE activeuser = VALUES(activeuser),percent=VALUES(percent);

set e = now();
insert into razor_log(op_type,op_name,op_starttime,op_date,affected_rows,duration) 
    values('runweekly','razor_sum_basic_channel_activeusers each channel active user and percent',s,e,row_count(),TIMESTAMPDIFF(SECOND,s,e));

insert into razor_log(op_type,op_name,op_starttime) 
    values('runweekly','-----finish runweekly-----',now());
    

end$$

DELIMITER ;

-- --------------------------------------------------------

--
-- 表的结构 `razor_deviceid_pushid`
--

CREATE TABLE IF NOT EXISTS `razor_deviceid_pushid` (
  `did` int(11) unsigned NOT NULL,
  `deviceid` varchar(128) NOT NULL,
  `pushid` varchar(128) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_deviceid_userid`
--

CREATE TABLE IF NOT EXISTS `razor_deviceid_userid` (
  `did` int(11) unsigned NOT NULL,
  `deviceid` varchar(128) NOT NULL,
  `userid` varchar(128) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_activity`
--

CREATE TABLE IF NOT EXISTS `razor_dim_activity` (
  `activity_sk` int(11) NOT NULL,
  `activity_name` varchar(512) NOT NULL,
  `product_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_date`
--

CREATE TABLE IF NOT EXISTS `razor_dim_date` (
  `date_sk` int(11) NOT NULL,
  `datevalue` date NOT NULL,
  `year` int(11) NOT NULL,
  `quarter` int(11) NOT NULL,
  `month` int(11) NOT NULL,
  `week` int(11) NOT NULL,
  `dayofweek` int(11) NOT NULL,
  `day` int(11) NOT NULL
) ENGINE=InnoDB AUTO_INCREMENT=4019 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_dim_date`
--

INSERT INTO `razor_dim_date` (`date_sk`, `datevalue`, `year`, `quarter`, `month`, `week`, `dayofweek`, `day`) VALUES
(1828, '2015-01-01', 2015, 1, 1, 0, 4, 2),
(1829, '2015-01-02', 2015, 1, 1, 0, 5, 3),
(1830, '2015-01-03', 2015, 1, 1, 1, 6, 4),
(1831, '2015-01-04', 2015, 1, 1, 1, 0, 5),
(1832, '2015-01-05', 2015, 1, 1, 1, 1, 6),
(1833, '2015-01-06', 2015, 1, 1, 1, 2, 7),
(1834, '2015-01-07', 2015, 1, 1, 1, 3, 8),
(1835, '2015-01-08', 2015, 1, 1, 1, 4, 9),
(1836, '2015-01-09', 2015, 1, 1, 1, 5, 10),
(1837, '2015-01-10', 2015, 1, 1, 2, 6, 11),
(1838, '2015-01-11', 2015, 1, 1, 2, 0, 12),
(1839, '2015-01-12', 2015, 1, 1, 2, 1, 13),
(1840, '2015-01-13', 2015, 1, 1, 2, 2, 14),
(1841, '2015-01-14', 2015, 1, 1, 2, 3, 15),
(1842, '2015-01-15', 2015, 1, 1, 2, 4, 16),
(1843, '2015-01-16', 2015, 1, 1, 2, 5, 17),
(1844, '2015-01-17', 2015, 1, 1, 3, 6, 18),
(1845, '2015-01-18', 2015, 1, 1, 3, 0, 19),
(1846, '2015-01-19', 2015, 1, 1, 3, 1, 20),
(1847, '2015-01-20', 2015, 1, 1, 3, 2, 21),
(1848, '2015-01-21', 2015, 1, 1, 3, 3, 22),
(1849, '2015-01-22', 2015, 1, 1, 3, 4, 23),
(1850, '2015-01-23', 2015, 1, 1, 3, 5, 24),
(1851, '2015-01-24', 2015, 1, 1, 4, 6, 25),
(1852, '2015-01-25', 2015, 1, 1, 4, 0, 26),
(1853, '2015-01-26', 2015, 1, 1, 4, 1, 27),
(1854, '2015-01-27', 2015, 1, 1, 4, 2, 28),
(1855, '2015-01-28', 2015, 1, 1, 4, 3, 29),
(1856, '2015-01-29', 2015, 1, 1, 4, 4, 30),
(1857, '2015-01-30', 2015, 1, 1, 4, 5, 31),
(1858, '2015-01-31', 2015, 1, 2, 5, 6, 1),
(1859, '2015-02-01', 2015, 1, 2, 5, 0, 2),
(1860, '2015-02-02', 2015, 1, 2, 5, 1, 3),
(1861, '2015-02-03', 2015, 1, 2, 5, 2, 4),
(1862, '2015-02-04', 2015, 1, 2, 5, 3, 5),
(1863, '2015-02-05', 2015, 1, 2, 5, 4, 6),
(1864, '2015-02-06', 2015, 1, 2, 5, 5, 7),
(1865, '2015-02-07', 2015, 1, 2, 6, 6, 8),
(1866, '2015-02-08', 2015, 1, 2, 6, 0, 9),
(1867, '2015-02-09', 2015, 1, 2, 6, 1, 10),
(1868, '2015-02-10', 2015, 1, 2, 6, 2, 11),
(1869, '2015-02-11', 2015, 1, 2, 6, 3, 12),
(1870, '2015-02-12', 2015, 1, 2, 6, 4, 13),
(1871, '2015-02-13', 2015, 1, 2, 6, 5, 14),
(1872, '2015-02-14', 2015, 1, 2, 7, 6, 15),
(1873, '2015-02-15', 2015, 1, 2, 7, 0, 16),
(1874, '2015-02-16', 2015, 1, 2, 7, 1, 17),
(1875, '2015-02-17', 2015, 1, 2, 7, 2, 18),
(1876, '2015-02-18', 2015, 1, 2, 7, 3, 19),
(1877, '2015-02-19', 2015, 1, 2, 7, 4, 20),
(1878, '2015-02-20', 2015, 1, 2, 7, 5, 21),
(1879, '2015-02-21', 2015, 1, 2, 8, 6, 22),
(1880, '2015-02-22', 2015, 1, 2, 8, 0, 23),
(1881, '2015-02-23', 2015, 1, 2, 8, 1, 24),
(1882, '2015-02-24', 2015, 1, 2, 8, 2, 25),
(1883, '2015-02-25', 2015, 1, 2, 8, 3, 26),
(1884, '2015-02-26', 2015, 1, 2, 8, 4, 27),
(1885, '2015-02-27', 2015, 1, 2, 8, 5, 28),
(1886, '2015-02-28', 2015, 1, 3, 9, 6, 1),
(1887, '2015-03-01', 2015, 1, 3, 9, 0, 2),
(1888, '2015-03-02', 2015, 1, 3, 9, 1, 3),
(1889, '2015-03-03', 2015, 1, 3, 9, 2, 4),
(1890, '2015-03-04', 2015, 1, 3, 9, 3, 5),
(1891, '2015-03-05', 2015, 1, 3, 9, 4, 6),
(1892, '2015-03-06', 2015, 1, 3, 9, 5, 7),
(1893, '2015-03-07', 2015, 1, 3, 10, 6, 8),
(1894, '2015-03-08', 2015, 1, 3, 10, 0, 9),
(1895, '2015-03-09', 2015, 1, 3, 10, 1, 10),
(1896, '2015-03-10', 2015, 1, 3, 10, 2, 11),
(1897, '2015-03-11', 2015, 1, 3, 10, 3, 12),
(1898, '2015-03-12', 2015, 1, 3, 10, 4, 13),
(1899, '2015-03-13', 2015, 1, 3, 10, 5, 14),
(1900, '2015-03-14', 2015, 1, 3, 11, 6, 15),
(1901, '2015-03-15', 2015, 1, 3, 11, 0, 16),
(1902, '2015-03-16', 2015, 1, 3, 11, 1, 17),
(1903, '2015-03-17', 2015, 1, 3, 11, 2, 18),
(1904, '2015-03-18', 2015, 1, 3, 11, 3, 19),
(1905, '2015-03-19', 2015, 1, 3, 11, 4, 20),
(1906, '2015-03-20', 2015, 1, 3, 11, 5, 21),
(1907, '2015-03-21', 2015, 1, 3, 12, 6, 22),
(1908, '2015-03-22', 2015, 1, 3, 12, 0, 23),
(1909, '2015-03-23', 2015, 1, 3, 12, 1, 24),
(1910, '2015-03-24', 2015, 1, 3, 12, 2, 25),
(1911, '2015-03-25', 2015, 1, 3, 12, 3, 26),
(1912, '2015-03-26', 2015, 1, 3, 12, 4, 27),
(1913, '2015-03-27', 2015, 1, 3, 12, 5, 28),
(1914, '2015-03-28', 2015, 1, 3, 13, 6, 29),
(1915, '2015-03-29', 2015, 1, 3, 13, 0, 30),
(1916, '2015-03-30', 2015, 1, 3, 13, 1, 31),
(1917, '2015-03-31', 2015, 2, 4, 13, 2, 1),
(1918, '2015-04-01', 2015, 2, 4, 13, 3, 2),
(1919, '2015-04-02', 2015, 2, 4, 13, 4, 3),
(1920, '2015-04-03', 2015, 2, 4, 13, 5, 4),
(1921, '2015-04-04', 2015, 2, 4, 14, 6, 5),
(1922, '2015-04-05', 2015, 2, 4, 14, 0, 6),
(1923, '2015-04-06', 2015, 2, 4, 14, 1, 7),
(1924, '2015-04-07', 2015, 2, 4, 14, 2, 8),
(1925, '2015-04-08', 2015, 2, 4, 14, 3, 9),
(1926, '2015-04-09', 2015, 2, 4, 14, 4, 10),
(1927, '2015-04-10', 2015, 2, 4, 14, 5, 11),
(1928, '2015-04-11', 2015, 2, 4, 15, 6, 12),
(1929, '2015-04-12', 2015, 2, 4, 15, 0, 13),
(1930, '2015-04-13', 2015, 2, 4, 15, 1, 14),
(1931, '2015-04-14', 2015, 2, 4, 15, 2, 15),
(1932, '2015-04-15', 2015, 2, 4, 15, 3, 16),
(1933, '2015-04-16', 2015, 2, 4, 15, 4, 17),
(1934, '2015-04-17', 2015, 2, 4, 15, 5, 18),
(1935, '2015-04-18', 2015, 2, 4, 16, 6, 19),
(1936, '2015-04-19', 2015, 2, 4, 16, 0, 20),
(1937, '2015-04-20', 2015, 2, 4, 16, 1, 21),
(1938, '2015-04-21', 2015, 2, 4, 16, 2, 22),
(1939, '2015-04-22', 2015, 2, 4, 16, 3, 23),
(1940, '2015-04-23', 2015, 2, 4, 16, 4, 24),
(1941, '2015-04-24', 2015, 2, 4, 16, 5, 25),
(1942, '2015-04-25', 2015, 2, 4, 17, 6, 26),
(1943, '2015-04-26', 2015, 2, 4, 17, 0, 27),
(1944, '2015-04-27', 2015, 2, 4, 17, 1, 28),
(1945, '2015-04-28', 2015, 2, 4, 17, 2, 29),
(1946, '2015-04-29', 2015, 2, 4, 17, 3, 30),
(1947, '2015-04-30', 2015, 2, 5, 17, 4, 1),
(1948, '2015-05-01', 2015, 2, 5, 17, 5, 2),
(1949, '2015-05-02', 2015, 2, 5, 18, 6, 3),
(1950, '2015-05-03', 2015, 2, 5, 18, 0, 4),
(1951, '2015-05-04', 2015, 2, 5, 18, 1, 5),
(1952, '2015-05-05', 2015, 2, 5, 18, 2, 6),
(1953, '2015-05-06', 2015, 2, 5, 18, 3, 7),
(1954, '2015-05-07', 2015, 2, 5, 18, 4, 8),
(1955, '2015-05-08', 2015, 2, 5, 18, 5, 9),
(1956, '2015-05-09', 2015, 2, 5, 19, 6, 10),
(1957, '2015-05-10', 2015, 2, 5, 19, 0, 11),
(1958, '2015-05-11', 2015, 2, 5, 19, 1, 12),
(1959, '2015-05-12', 2015, 2, 5, 19, 2, 13),
(1960, '2015-05-13', 2015, 2, 5, 19, 3, 14),
(1961, '2015-05-14', 2015, 2, 5, 19, 4, 15),
(1962, '2015-05-15', 2015, 2, 5, 19, 5, 16),
(1963, '2015-05-16', 2015, 2, 5, 20, 6, 17),
(1964, '2015-05-17', 2015, 2, 5, 20, 0, 18),
(1965, '2015-05-18', 2015, 2, 5, 20, 1, 19),
(1966, '2015-05-19', 2015, 2, 5, 20, 2, 20),
(1967, '2015-05-20', 2015, 2, 5, 20, 3, 21),
(1968, '2015-05-21', 2015, 2, 5, 20, 4, 22),
(1969, '2015-05-22', 2015, 2, 5, 20, 5, 23),
(1970, '2015-05-23', 2015, 2, 5, 21, 6, 24),
(1971, '2015-05-24', 2015, 2, 5, 21, 0, 25),
(1972, '2015-05-25', 2015, 2, 5, 21, 1, 26),
(1973, '2015-05-26', 2015, 2, 5, 21, 2, 27),
(1974, '2015-05-27', 2015, 2, 5, 21, 3, 28),
(1975, '2015-05-28', 2015, 2, 5, 21, 4, 29),
(1976, '2015-05-29', 2015, 2, 5, 21, 5, 30),
(1977, '2015-05-30', 2015, 2, 5, 22, 6, 31),
(1978, '2015-05-31', 2015, 2, 6, 22, 0, 1),
(1979, '2015-06-01', 2015, 2, 6, 22, 1, 2),
(1980, '2015-06-02', 2015, 2, 6, 22, 2, 3),
(1981, '2015-06-03', 2015, 2, 6, 22, 3, 4),
(1982, '2015-06-04', 2015, 2, 6, 22, 4, 5),
(1983, '2015-06-05', 2015, 2, 6, 22, 5, 6),
(1984, '2015-06-06', 2015, 2, 6, 23, 6, 7),
(1985, '2015-06-07', 2015, 2, 6, 23, 0, 8),
(1986, '2015-06-08', 2015, 2, 6, 23, 1, 9),
(1987, '2015-06-09', 2015, 2, 6, 23, 2, 10),
(1988, '2015-06-10', 2015, 2, 6, 23, 3, 11),
(1989, '2015-06-11', 2015, 2, 6, 23, 4, 12),
(1990, '2015-06-12', 2015, 2, 6, 23, 5, 13),
(1991, '2015-06-13', 2015, 2, 6, 24, 6, 14),
(1992, '2015-06-14', 2015, 2, 6, 24, 0, 15),
(1993, '2015-06-15', 2015, 2, 6, 24, 1, 16),
(1994, '2015-06-16', 2015, 2, 6, 24, 2, 17),
(1995, '2015-06-17', 2015, 2, 6, 24, 3, 18),
(1996, '2015-06-18', 2015, 2, 6, 24, 4, 19),
(1997, '2015-06-19', 2015, 2, 6, 24, 5, 20),
(1998, '2015-06-20', 2015, 2, 6, 25, 6, 21),
(1999, '2015-06-21', 2015, 2, 6, 25, 0, 22),
(2000, '2015-06-22', 2015, 2, 6, 25, 1, 23),
(2001, '2015-06-23', 2015, 2, 6, 25, 2, 24),
(2002, '2015-06-24', 2015, 2, 6, 25, 3, 25),
(2003, '2015-06-25', 2015, 2, 6, 25, 4, 26),
(2004, '2015-06-26', 2015, 2, 6, 25, 5, 27),
(2005, '2015-06-27', 2015, 2, 6, 26, 6, 28),
(2006, '2015-06-28', 2015, 2, 6, 26, 0, 29),
(2007, '2015-06-29', 2015, 2, 6, 26, 1, 30),
(2008, '2015-06-30', 2015, 3, 7, 26, 2, 1),
(2009, '2015-07-01', 2015, 3, 7, 26, 3, 2),
(2010, '2015-07-02', 2015, 3, 7, 26, 4, 3),
(2011, '2015-07-03', 2015, 3, 7, 26, 5, 4),
(2012, '2015-07-04', 2015, 3, 7, 27, 6, 5),
(2013, '2015-07-05', 2015, 3, 7, 27, 0, 6),
(2014, '2015-07-06', 2015, 3, 7, 27, 1, 7),
(2015, '2015-07-07', 2015, 3, 7, 27, 2, 8),
(2016, '2015-07-08', 2015, 3, 7, 27, 3, 9),
(2017, '2015-07-09', 2015, 3, 7, 27, 4, 10),
(2018, '2015-07-10', 2015, 3, 7, 27, 5, 11),
(2019, '2015-07-11', 2015, 3, 7, 28, 6, 12),
(2020, '2015-07-12', 2015, 3, 7, 28, 0, 13),
(2021, '2015-07-13', 2015, 3, 7, 28, 1, 14),
(2022, '2015-07-14', 2015, 3, 7, 28, 2, 15),
(2023, '2015-07-15', 2015, 3, 7, 28, 3, 16),
(2024, '2015-07-16', 2015, 3, 7, 28, 4, 17),
(2025, '2015-07-17', 2015, 3, 7, 28, 5, 18),
(2026, '2015-07-18', 2015, 3, 7, 29, 6, 19),
(2027, '2015-07-19', 2015, 3, 7, 29, 0, 20),
(2028, '2015-07-20', 2015, 3, 7, 29, 1, 21),
(2029, '2015-07-21', 2015, 3, 7, 29, 2, 22),
(2030, '2015-07-22', 2015, 3, 7, 29, 3, 23),
(2031, '2015-07-23', 2015, 3, 7, 29, 4, 24),
(2032, '2015-07-24', 2015, 3, 7, 29, 5, 25),
(2033, '2015-07-25', 2015, 3, 7, 30, 6, 26),
(2034, '2015-07-26', 2015, 3, 7, 30, 0, 27),
(2035, '2015-07-27', 2015, 3, 7, 30, 1, 28),
(2036, '2015-07-28', 2015, 3, 7, 30, 2, 29),
(2037, '2015-07-29', 2015, 3, 7, 30, 3, 30),
(2038, '2015-07-30', 2015, 3, 7, 30, 4, 31),
(2039, '2015-07-31', 2015, 3, 8, 30, 5, 1),
(2040, '2015-08-01', 2015, 3, 8, 31, 6, 2),
(2041, '2015-08-02', 2015, 3, 8, 31, 0, 3),
(2042, '2015-08-03', 2015, 3, 8, 31, 1, 4),
(2043, '2015-08-04', 2015, 3, 8, 31, 2, 5),
(2044, '2015-08-05', 2015, 3, 8, 31, 3, 6),
(2045, '2015-08-06', 2015, 3, 8, 31, 4, 7),
(2046, '2015-08-07', 2015, 3, 8, 31, 5, 8),
(2047, '2015-08-08', 2015, 3, 8, 32, 6, 9),
(2048, '2015-08-09', 2015, 3, 8, 32, 0, 10),
(2049, '2015-08-10', 2015, 3, 8, 32, 1, 11),
(2050, '2015-08-11', 2015, 3, 8, 32, 2, 12),
(2051, '2015-08-12', 2015, 3, 8, 32, 3, 13),
(2052, '2015-08-13', 2015, 3, 8, 32, 4, 14),
(2053, '2015-08-14', 2015, 3, 8, 32, 5, 15),
(2054, '2015-08-15', 2015, 3, 8, 33, 6, 16),
(2055, '2015-08-16', 2015, 3, 8, 33, 0, 17),
(2056, '2015-08-17', 2015, 3, 8, 33, 1, 18),
(2057, '2015-08-18', 2015, 3, 8, 33, 2, 19),
(2058, '2015-08-19', 2015, 3, 8, 33, 3, 20),
(2059, '2015-08-20', 2015, 3, 8, 33, 4, 21),
(2060, '2015-08-21', 2015, 3, 8, 33, 5, 22),
(2061, '2015-08-22', 2015, 3, 8, 34, 6, 23),
(2062, '2015-08-23', 2015, 3, 8, 34, 0, 24),
(2063, '2015-08-24', 2015, 3, 8, 34, 1, 25),
(2064, '2015-08-25', 2015, 3, 8, 34, 2, 26),
(2065, '2015-08-26', 2015, 3, 8, 34, 3, 27),
(2066, '2015-08-27', 2015, 3, 8, 34, 4, 28),
(2067, '2015-08-28', 2015, 3, 8, 34, 5, 29),
(2068, '2015-08-29', 2015, 3, 8, 35, 6, 30),
(2069, '2015-08-30', 2015, 3, 8, 35, 0, 31),
(2070, '2015-08-31', 2015, 3, 9, 35, 1, 1),
(2071, '2015-09-01', 2015, 3, 9, 35, 2, 2),
(2072, '2015-09-02', 2015, 3, 9, 35, 3, 3),
(2073, '2015-09-03', 2015, 3, 9, 35, 4, 4),
(2074, '2015-09-04', 2015, 3, 9, 35, 5, 5),
(2075, '2015-09-05', 2015, 3, 9, 36, 6, 6),
(2076, '2015-09-06', 2015, 3, 9, 36, 0, 7),
(2077, '2015-09-07', 2015, 3, 9, 36, 1, 8),
(2078, '2015-09-08', 2015, 3, 9, 36, 2, 9),
(2079, '2015-09-09', 2015, 3, 9, 36, 3, 10),
(2080, '2015-09-10', 2015, 3, 9, 36, 4, 11),
(2081, '2015-09-11', 2015, 3, 9, 36, 5, 12),
(2082, '2015-09-12', 2015, 3, 9, 37, 6, 13),
(2083, '2015-09-13', 2015, 3, 9, 37, 0, 14),
(2084, '2015-09-14', 2015, 3, 9, 37, 1, 15),
(2085, '2015-09-15', 2015, 3, 9, 37, 2, 16),
(2086, '2015-09-16', 2015, 3, 9, 37, 3, 17),
(2087, '2015-09-17', 2015, 3, 9, 37, 4, 18),
(2088, '2015-09-18', 2015, 3, 9, 37, 5, 19),
(2089, '2015-09-19', 2015, 3, 9, 38, 6, 20),
(2090, '2015-09-20', 2015, 3, 9, 38, 0, 21),
(2091, '2015-09-21', 2015, 3, 9, 38, 1, 22),
(2092, '2015-09-22', 2015, 3, 9, 38, 2, 23),
(2093, '2015-09-23', 2015, 3, 9, 38, 3, 24),
(2094, '2015-09-24', 2015, 3, 9, 38, 4, 25),
(2095, '2015-09-25', 2015, 3, 9, 38, 5, 26),
(2096, '2015-09-26', 2015, 3, 9, 39, 6, 27),
(2097, '2015-09-27', 2015, 3, 9, 39, 0, 28),
(2098, '2015-09-28', 2015, 3, 9, 39, 1, 29),
(2099, '2015-09-29', 2015, 3, 9, 39, 2, 30),
(2100, '2015-09-30', 2015, 4, 10, 39, 3, 1),
(2101, '2015-10-01', 2015, 4, 10, 39, 4, 2),
(2102, '2015-10-02', 2015, 4, 10, 39, 5, 3),
(2103, '2015-10-03', 2015, 4, 10, 40, 6, 4),
(2104, '2015-10-04', 2015, 4, 10, 40, 0, 5),
(2105, '2015-10-05', 2015, 4, 10, 40, 1, 6),
(2106, '2015-10-06', 2015, 4, 10, 40, 2, 7),
(2107, '2015-10-07', 2015, 4, 10, 40, 3, 8),
(2108, '2015-10-08', 2015, 4, 10, 40, 4, 9),
(2109, '2015-10-09', 2015, 4, 10, 40, 5, 10),
(2110, '2015-10-10', 2015, 4, 10, 41, 6, 11),
(2111, '2015-10-11', 2015, 4, 10, 41, 0, 12),
(2112, '2015-10-12', 2015, 4, 10, 41, 1, 13),
(2113, '2015-10-13', 2015, 4, 10, 41, 2, 14),
(2114, '2015-10-14', 2015, 4, 10, 41, 3, 15),
(2115, '2015-10-15', 2015, 4, 10, 41, 4, 16),
(2116, '2015-10-16', 2015, 4, 10, 41, 5, 17),
(2117, '2015-10-17', 2015, 4, 10, 42, 6, 18),
(2118, '2015-10-18', 2015, 4, 10, 42, 0, 19),
(2119, '2015-10-19', 2015, 4, 10, 42, 1, 20),
(2120, '2015-10-20', 2015, 4, 10, 42, 2, 21),
(2121, '2015-10-21', 2015, 4, 10, 42, 3, 22),
(2122, '2015-10-22', 2015, 4, 10, 42, 4, 23),
(2123, '2015-10-23', 2015, 4, 10, 42, 5, 24),
(2124, '2015-10-24', 2015, 4, 10, 43, 6, 25),
(2125, '2015-10-25', 2015, 4, 10, 43, 0, 26),
(2126, '2015-10-26', 2015, 4, 10, 43, 1, 27),
(2127, '2015-10-27', 2015, 4, 10, 43, 2, 28),
(2128, '2015-10-28', 2015, 4, 10, 43, 3, 29),
(2129, '2015-10-29', 2015, 4, 10, 43, 4, 30),
(2130, '2015-10-30', 2015, 4, 10, 43, 5, 31),
(2131, '2015-10-31', 2015, 4, 11, 44, 6, 1),
(2132, '2015-11-01', 2015, 4, 11, 44, 0, 2),
(2133, '2015-11-02', 2015, 4, 11, 44, 1, 3),
(2134, '2015-11-03', 2015, 4, 11, 44, 2, 4),
(2135, '2015-11-04', 2015, 4, 11, 44, 3, 5),
(2136, '2015-11-05', 2015, 4, 11, 44, 4, 6),
(2137, '2015-11-06', 2015, 4, 11, 44, 5, 7),
(2138, '2015-11-07', 2015, 4, 11, 45, 6, 8),
(2139, '2015-11-08', 2015, 4, 11, 45, 0, 9),
(2140, '2015-11-09', 2015, 4, 11, 45, 1, 10),
(2141, '2015-11-10', 2015, 4, 11, 45, 2, 11),
(2142, '2015-11-11', 2015, 4, 11, 45, 3, 12),
(2143, '2015-11-12', 2015, 4, 11, 45, 4, 13),
(2144, '2015-11-13', 2015, 4, 11, 45, 5, 14),
(2145, '2015-11-14', 2015, 4, 11, 46, 6, 15),
(2146, '2015-11-15', 2015, 4, 11, 46, 0, 16),
(2147, '2015-11-16', 2015, 4, 11, 46, 1, 17),
(2148, '2015-11-17', 2015, 4, 11, 46, 2, 18),
(2149, '2015-11-18', 2015, 4, 11, 46, 3, 19),
(2150, '2015-11-19', 2015, 4, 11, 46, 4, 20),
(2151, '2015-11-20', 2015, 4, 11, 46, 5, 21),
(2152, '2015-11-21', 2015, 4, 11, 47, 6, 22),
(2153, '2015-11-22', 2015, 4, 11, 47, 0, 23),
(2154, '2015-11-23', 2015, 4, 11, 47, 1, 24),
(2155, '2015-11-24', 2015, 4, 11, 47, 2, 25),
(2156, '2015-11-25', 2015, 4, 11, 47, 3, 26),
(2157, '2015-11-26', 2015, 4, 11, 47, 4, 27),
(2158, '2015-11-27', 2015, 4, 11, 47, 5, 28),
(2159, '2015-11-28', 2015, 4, 11, 48, 6, 29),
(2160, '2015-11-29', 2015, 4, 11, 48, 0, 30),
(2161, '2015-11-30', 2015, 4, 12, 48, 1, 1),
(2162, '2015-12-01', 2015, 4, 12, 48, 2, 2),
(2163, '2015-12-02', 2015, 4, 12, 48, 3, 3),
(2164, '2015-12-03', 2015, 4, 12, 48, 4, 4),
(2165, '2015-12-04', 2015, 4, 12, 48, 5, 5),
(2166, '2015-12-05', 2015, 4, 12, 49, 6, 6),
(2167, '2015-12-06', 2015, 4, 12, 49, 0, 7),
(2168, '2015-12-07', 2015, 4, 12, 49, 1, 8),
(2169, '2015-12-08', 2015, 4, 12, 49, 2, 9),
(2170, '2015-12-09', 2015, 4, 12, 49, 3, 10),
(2171, '2015-12-10', 2015, 4, 12, 49, 4, 11),
(2172, '2015-12-11', 2015, 4, 12, 49, 5, 12),
(2173, '2015-12-12', 2015, 4, 12, 50, 6, 13),
(2174, '2015-12-13', 2015, 4, 12, 50, 0, 14),
(2175, '2015-12-14', 2015, 4, 12, 50, 1, 15),
(2176, '2015-12-15', 2015, 4, 12, 50, 2, 16),
(2177, '2015-12-16', 2015, 4, 12, 50, 3, 17),
(2178, '2015-12-17', 2015, 4, 12, 50, 4, 18),
(2179, '2015-12-18', 2015, 4, 12, 50, 5, 19),
(2180, '2015-12-19', 2015, 4, 12, 51, 6, 20),
(2181, '2015-12-20', 2015, 4, 12, 51, 0, 21),
(2182, '2015-12-21', 2015, 4, 12, 51, 1, 22),
(2183, '2015-12-22', 2015, 4, 12, 51, 2, 23),
(2184, '2015-12-23', 2015, 4, 12, 51, 3, 24),
(2185, '2015-12-24', 2015, 4, 12, 51, 4, 25),
(2186, '2015-12-25', 2015, 4, 12, 51, 5, 26),
(2187, '2015-12-26', 2015, 4, 12, 52, 6, 27),
(2188, '2015-12-27', 2015, 4, 12, 52, 0, 28),
(2189, '2015-12-28', 2015, 4, 12, 52, 1, 29),
(2190, '2015-12-29', 2015, 4, 12, 52, 2, 30),
(2191, '2015-12-30', 2015, 4, 12, 52, 3, 31),
(2192, '2015-12-31', 2016, 1, 1, 0, 4, 1),
(2193, '2016-01-01', 2016, 1, 1, 0, 5, 2),
(2194, '2016-01-02', 2016, 1, 1, 1, 6, 3),
(2195, '2016-01-03', 2016, 1, 1, 1, 0, 4),
(2196, '2016-01-04', 2016, 1, 1, 1, 1, 5),
(2197, '2016-01-05', 2016, 1, 1, 1, 2, 6),
(2198, '2016-01-06', 2016, 1, 1, 1, 3, 7),
(2199, '2016-01-07', 2016, 1, 1, 1, 4, 8),
(2200, '2016-01-08', 2016, 1, 1, 1, 5, 9),
(2201, '2016-01-09', 2016, 1, 1, 2, 6, 10),
(2202, '2016-01-10', 2016, 1, 1, 2, 0, 11),
(2203, '2016-01-11', 2016, 1, 1, 2, 1, 12),
(2204, '2016-01-12', 2016, 1, 1, 2, 2, 13),
(2205, '2016-01-13', 2016, 1, 1, 2, 3, 14),
(2206, '2016-01-14', 2016, 1, 1, 2, 4, 15),
(2207, '2016-01-15', 2016, 1, 1, 2, 5, 16),
(2208, '2016-01-16', 2016, 1, 1, 3, 6, 17),
(2209, '2016-01-17', 2016, 1, 1, 3, 0, 18),
(2210, '2016-01-18', 2016, 1, 1, 3, 1, 19),
(2211, '2016-01-19', 2016, 1, 1, 3, 2, 20),
(2212, '2016-01-20', 2016, 1, 1, 3, 3, 21),
(2213, '2016-01-21', 2016, 1, 1, 3, 4, 22),
(2214, '2016-01-22', 2016, 1, 1, 3, 5, 23),
(2215, '2016-01-23', 2016, 1, 1, 4, 6, 24),
(2216, '2016-01-24', 2016, 1, 1, 4, 0, 25),
(2217, '2016-01-25', 2016, 1, 1, 4, 1, 26),
(2218, '2016-01-26', 2016, 1, 1, 4, 2, 27),
(2219, '2016-01-27', 2016, 1, 1, 4, 3, 28),
(2220, '2016-01-28', 2016, 1, 1, 4, 4, 29),
(2221, '2016-01-29', 2016, 1, 1, 4, 5, 30),
(2222, '2016-01-30', 2016, 1, 1, 5, 6, 31),
(2223, '2016-01-31', 2016, 1, 2, 5, 0, 1),
(2224, '2016-02-01', 2016, 1, 2, 5, 1, 2),
(2225, '2016-02-02', 2016, 1, 2, 5, 2, 3),
(2226, '2016-02-03', 2016, 1, 2, 5, 3, 4),
(2227, '2016-02-04', 2016, 1, 2, 5, 4, 5),
(2228, '2016-02-05', 2016, 1, 2, 5, 5, 6),
(2229, '2016-02-06', 2016, 1, 2, 6, 6, 7),
(2230, '2016-02-07', 2016, 1, 2, 6, 0, 8),
(2231, '2016-02-08', 2016, 1, 2, 6, 1, 9),
(2232, '2016-02-09', 2016, 1, 2, 6, 2, 10),
(2233, '2016-02-10', 2016, 1, 2, 6, 3, 11),
(2234, '2016-02-11', 2016, 1, 2, 6, 4, 12),
(2235, '2016-02-12', 2016, 1, 2, 6, 5, 13),
(2236, '2016-02-13', 2016, 1, 2, 7, 6, 14),
(2237, '2016-02-14', 2016, 1, 2, 7, 0, 15),
(2238, '2016-02-15', 2016, 1, 2, 7, 1, 16),
(2239, '2016-02-16', 2016, 1, 2, 7, 2, 17),
(2240, '2016-02-17', 2016, 1, 2, 7, 3, 18),
(2241, '2016-02-18', 2016, 1, 2, 7, 4, 19),
(2242, '2016-02-19', 2016, 1, 2, 7, 5, 20),
(2243, '2016-02-20', 2016, 1, 2, 8, 6, 21),
(2244, '2016-02-21', 2016, 1, 2, 8, 0, 22),
(2245, '2016-02-22', 2016, 1, 2, 8, 1, 23),
(2246, '2016-02-23', 2016, 1, 2, 8, 2, 24),
(2247, '2016-02-24', 2016, 1, 2, 8, 3, 25),
(2248, '2016-02-25', 2016, 1, 2, 8, 4, 26),
(2249, '2016-02-26', 2016, 1, 2, 8, 5, 27),
(2250, '2016-02-27', 2016, 1, 2, 9, 6, 28),
(2251, '2016-02-28', 2016, 1, 2, 9, 0, 29),
(2252, '2016-02-29', 2016, 1, 3, 9, 1, 1),
(2253, '2016-03-01', 2016, 1, 3, 9, 2, 2),
(2254, '2016-03-02', 2016, 1, 3, 9, 3, 3),
(2255, '2016-03-03', 2016, 1, 3, 9, 4, 4),
(2256, '2016-03-04', 2016, 1, 3, 9, 5, 5),
(2257, '2016-03-05', 2016, 1, 3, 10, 6, 6),
(2258, '2016-03-06', 2016, 1, 3, 10, 0, 7),
(2259, '2016-03-07', 2016, 1, 3, 10, 1, 8),
(2260, '2016-03-08', 2016, 1, 3, 10, 2, 9),
(2261, '2016-03-09', 2016, 1, 3, 10, 3, 10),
(2262, '2016-03-10', 2016, 1, 3, 10, 4, 11),
(2263, '2016-03-11', 2016, 1, 3, 10, 5, 12),
(2264, '2016-03-12', 2016, 1, 3, 11, 6, 13),
(2265, '2016-03-13', 2016, 1, 3, 11, 0, 14),
(2266, '2016-03-14', 2016, 1, 3, 11, 1, 15),
(2267, '2016-03-15', 2016, 1, 3, 11, 2, 16),
(2268, '2016-03-16', 2016, 1, 3, 11, 3, 17),
(2269, '2016-03-17', 2016, 1, 3, 11, 4, 18),
(2270, '2016-03-18', 2016, 1, 3, 11, 5, 19),
(2271, '2016-03-19', 2016, 1, 3, 12, 6, 20),
(2272, '2016-03-20', 2016, 1, 3, 12, 0, 21),
(2273, '2016-03-21', 2016, 1, 3, 12, 1, 22),
(2274, '2016-03-22', 2016, 1, 3, 12, 2, 23),
(2275, '2016-03-23', 2016, 1, 3, 12, 3, 24),
(2276, '2016-03-24', 2016, 1, 3, 12, 4, 25),
(2277, '2016-03-25', 2016, 1, 3, 12, 5, 26),
(2278, '2016-03-26', 2016, 1, 3, 13, 6, 27),
(2279, '2016-03-27', 2016, 1, 3, 13, 0, 28),
(2280, '2016-03-28', 2016, 1, 3, 13, 1, 29),
(2281, '2016-03-29', 2016, 1, 3, 13, 2, 30),
(2282, '2016-03-30', 2016, 1, 3, 13, 3, 31),
(2283, '2016-03-31', 2016, 2, 4, 13, 4, 1),
(2284, '2016-04-01', 2016, 2, 4, 13, 5, 2),
(2285, '2016-04-02', 2016, 2, 4, 14, 6, 3),
(2286, '2016-04-03', 2016, 2, 4, 14, 0, 4),
(2287, '2016-04-04', 2016, 2, 4, 14, 1, 5),
(2288, '2016-04-05', 2016, 2, 4, 14, 2, 6),
(2289, '2016-04-06', 2016, 2, 4, 14, 3, 7),
(2290, '2016-04-07', 2016, 2, 4, 14, 4, 8),
(2291, '2016-04-08', 2016, 2, 4, 14, 5, 9),
(2292, '2016-04-09', 2016, 2, 4, 15, 6, 10),
(2293, '2016-04-10', 2016, 2, 4, 15, 0, 11),
(2294, '2016-04-11', 2016, 2, 4, 15, 1, 12),
(2295, '2016-04-12', 2016, 2, 4, 15, 2, 13),
(2296, '2016-04-13', 2016, 2, 4, 15, 3, 14),
(2297, '2016-04-14', 2016, 2, 4, 15, 4, 15),
(2298, '2016-04-15', 2016, 2, 4, 15, 5, 16),
(2299, '2016-04-16', 2016, 2, 4, 16, 6, 17),
(2300, '2016-04-17', 2016, 2, 4, 16, 0, 18),
(2301, '2016-04-18', 2016, 2, 4, 16, 1, 19),
(2302, '2016-04-19', 2016, 2, 4, 16, 2, 20),
(2303, '2016-04-20', 2016, 2, 4, 16, 3, 21),
(2304, '2016-04-21', 2016, 2, 4, 16, 4, 22),
(2305, '2016-04-22', 2016, 2, 4, 16, 5, 23),
(2306, '2016-04-23', 2016, 2, 4, 17, 6, 24),
(2307, '2016-04-24', 2016, 2, 4, 17, 0, 25),
(2308, '2016-04-25', 2016, 2, 4, 17, 1, 26),
(2309, '2016-04-26', 2016, 2, 4, 17, 2, 27),
(2310, '2016-04-27', 2016, 2, 4, 17, 3, 28),
(2311, '2016-04-28', 2016, 2, 4, 17, 4, 29),
(2312, '2016-04-29', 2016, 2, 4, 17, 5, 30),
(2313, '2016-04-30', 2016, 2, 5, 18, 6, 1),
(2314, '2016-05-01', 2016, 2, 5, 18, 0, 2),
(2315, '2016-05-02', 2016, 2, 5, 18, 1, 3),
(2316, '2016-05-03', 2016, 2, 5, 18, 2, 4),
(2317, '2016-05-04', 2016, 2, 5, 18, 3, 5),
(2318, '2016-05-05', 2016, 2, 5, 18, 4, 6),
(2319, '2016-05-06', 2016, 2, 5, 18, 5, 7),
(2320, '2016-05-07', 2016, 2, 5, 19, 6, 8),
(2321, '2016-05-08', 2016, 2, 5, 19, 0, 9),
(2322, '2016-05-09', 2016, 2, 5, 19, 1, 10),
(2323, '2016-05-10', 2016, 2, 5, 19, 2, 11),
(2324, '2016-05-11', 2016, 2, 5, 19, 3, 12),
(2325, '2016-05-12', 2016, 2, 5, 19, 4, 13),
(2326, '2016-05-13', 2016, 2, 5, 19, 5, 14),
(2327, '2016-05-14', 2016, 2, 5, 20, 6, 15),
(2328, '2016-05-15', 2016, 2, 5, 20, 0, 16),
(2329, '2016-05-16', 2016, 2, 5, 20, 1, 17),
(2330, '2016-05-17', 2016, 2, 5, 20, 2, 18),
(2331, '2016-05-18', 2016, 2, 5, 20, 3, 19),
(2332, '2016-05-19', 2016, 2, 5, 20, 4, 20),
(2333, '2016-05-20', 2016, 2, 5, 20, 5, 21),
(2334, '2016-05-21', 2016, 2, 5, 21, 6, 22),
(2335, '2016-05-22', 2016, 2, 5, 21, 0, 23),
(2336, '2016-05-23', 2016, 2, 5, 21, 1, 24),
(2337, '2016-05-24', 2016, 2, 5, 21, 2, 25),
(2338, '2016-05-25', 2016, 2, 5, 21, 3, 26),
(2339, '2016-05-26', 2016, 2, 5, 21, 4, 27),
(2340, '2016-05-27', 2016, 2, 5, 21, 5, 28),
(2341, '2016-05-28', 2016, 2, 5, 22, 6, 29),
(2342, '2016-05-29', 2016, 2, 5, 22, 0, 30),
(2343, '2016-05-30', 2016, 2, 5, 22, 1, 31),
(2344, '2016-05-31', 2016, 2, 6, 22, 2, 1),
(2345, '2016-06-01', 2016, 2, 6, 22, 3, 2),
(2346, '2016-06-02', 2016, 2, 6, 22, 4, 3),
(2347, '2016-06-03', 2016, 2, 6, 22, 5, 4),
(2348, '2016-06-04', 2016, 2, 6, 23, 6, 5),
(2349, '2016-06-05', 2016, 2, 6, 23, 0, 6),
(2350, '2016-06-06', 2016, 2, 6, 23, 1, 7),
(2351, '2016-06-07', 2016, 2, 6, 23, 2, 8),
(2352, '2016-06-08', 2016, 2, 6, 23, 3, 9),
(2353, '2016-06-09', 2016, 2, 6, 23, 4, 10),
(2354, '2016-06-10', 2016, 2, 6, 23, 5, 11),
(2355, '2016-06-11', 2016, 2, 6, 24, 6, 12),
(2356, '2016-06-12', 2016, 2, 6, 24, 0, 13),
(2357, '2016-06-13', 2016, 2, 6, 24, 1, 14),
(2358, '2016-06-14', 2016, 2, 6, 24, 2, 15),
(2359, '2016-06-15', 2016, 2, 6, 24, 3, 16),
(2360, '2016-06-16', 2016, 2, 6, 24, 4, 17),
(2361, '2016-06-17', 2016, 2, 6, 24, 5, 18),
(2362, '2016-06-18', 2016, 2, 6, 25, 6, 19),
(2363, '2016-06-19', 2016, 2, 6, 25, 0, 20),
(2364, '2016-06-20', 2016, 2, 6, 25, 1, 21),
(2365, '2016-06-21', 2016, 2, 6, 25, 2, 22),
(2366, '2016-06-22', 2016, 2, 6, 25, 3, 23),
(2367, '2016-06-23', 2016, 2, 6, 25, 4, 24),
(2368, '2016-06-24', 2016, 2, 6, 25, 5, 25),
(2369, '2016-06-25', 2016, 2, 6, 26, 6, 26),
(2370, '2016-06-26', 2016, 2, 6, 26, 0, 27),
(2371, '2016-06-27', 2016, 2, 6, 26, 1, 28),
(2372, '2016-06-28', 2016, 2, 6, 26, 2, 29),
(2373, '2016-06-29', 2016, 2, 6, 26, 3, 30),
(2374, '2016-06-30', 2016, 3, 7, 26, 4, 1),
(2375, '2016-07-01', 2016, 3, 7, 26, 5, 2),
(2376, '2016-07-02', 2016, 3, 7, 27, 6, 3),
(2377, '2016-07-03', 2016, 3, 7, 27, 0, 4),
(2378, '2016-07-04', 2016, 3, 7, 27, 1, 5),
(2379, '2016-07-05', 2016, 3, 7, 27, 2, 6),
(2380, '2016-07-06', 2016, 3, 7, 27, 3, 7),
(2381, '2016-07-07', 2016, 3, 7, 27, 4, 8),
(2382, '2016-07-08', 2016, 3, 7, 27, 5, 9),
(2383, '2016-07-09', 2016, 3, 7, 28, 6, 10),
(2384, '2016-07-10', 2016, 3, 7, 28, 0, 11),
(2385, '2016-07-11', 2016, 3, 7, 28, 1, 12),
(2386, '2016-07-12', 2016, 3, 7, 28, 2, 13),
(2387, '2016-07-13', 2016, 3, 7, 28, 3, 14),
(2388, '2016-07-14', 2016, 3, 7, 28, 4, 15),
(2389, '2016-07-15', 2016, 3, 7, 28, 5, 16),
(2390, '2016-07-16', 2016, 3, 7, 29, 6, 17),
(2391, '2016-07-17', 2016, 3, 7, 29, 0, 18),
(2392, '2016-07-18', 2016, 3, 7, 29, 1, 19),
(2393, '2016-07-19', 2016, 3, 7, 29, 2, 20),
(2394, '2016-07-20', 2016, 3, 7, 29, 3, 21),
(2395, '2016-07-21', 2016, 3, 7, 29, 4, 22),
(2396, '2016-07-22', 2016, 3, 7, 29, 5, 23),
(2397, '2016-07-23', 2016, 3, 7, 30, 6, 24),
(2398, '2016-07-24', 2016, 3, 7, 30, 0, 25),
(2399, '2016-07-25', 2016, 3, 7, 30, 1, 26),
(2400, '2016-07-26', 2016, 3, 7, 30, 2, 27),
(2401, '2016-07-27', 2016, 3, 7, 30, 3, 28),
(2402, '2016-07-28', 2016, 3, 7, 30, 4, 29),
(2403, '2016-07-29', 2016, 3, 7, 30, 5, 30),
(2404, '2016-07-30', 2016, 3, 7, 31, 6, 31),
(2405, '2016-07-31', 2016, 3, 8, 31, 0, 1),
(2406, '2016-08-01', 2016, 3, 8, 31, 1, 2),
(2407, '2016-08-02', 2016, 3, 8, 31, 2, 3),
(2408, '2016-08-03', 2016, 3, 8, 31, 3, 4),
(2409, '2016-08-04', 2016, 3, 8, 31, 4, 5),
(2410, '2016-08-05', 2016, 3, 8, 31, 5, 6),
(2411, '2016-08-06', 2016, 3, 8, 32, 6, 7),
(2412, '2016-08-07', 2016, 3, 8, 32, 0, 8),
(2413, '2016-08-08', 2016, 3, 8, 32, 1, 9),
(2414, '2016-08-09', 2016, 3, 8, 32, 2, 10),
(2415, '2016-08-10', 2016, 3, 8, 32, 3, 11),
(2416, '2016-08-11', 2016, 3, 8, 32, 4, 12),
(2417, '2016-08-12', 2016, 3, 8, 32, 5, 13),
(2418, '2016-08-13', 2016, 3, 8, 33, 6, 14),
(2419, '2016-08-14', 2016, 3, 8, 33, 0, 15),
(2420, '2016-08-15', 2016, 3, 8, 33, 1, 16),
(2421, '2016-08-16', 2016, 3, 8, 33, 2, 17),
(2422, '2016-08-17', 2016, 3, 8, 33, 3, 18),
(2423, '2016-08-18', 2016, 3, 8, 33, 4, 19),
(2424, '2016-08-19', 2016, 3, 8, 33, 5, 20),
(2425, '2016-08-20', 2016, 3, 8, 34, 6, 21),
(2426, '2016-08-21', 2016, 3, 8, 34, 0, 22),
(2427, '2016-08-22', 2016, 3, 8, 34, 1, 23),
(2428, '2016-08-23', 2016, 3, 8, 34, 2, 24),
(2429, '2016-08-24', 2016, 3, 8, 34, 3, 25),
(2430, '2016-08-25', 2016, 3, 8, 34, 4, 26),
(2431, '2016-08-26', 2016, 3, 8, 34, 5, 27),
(2432, '2016-08-27', 2016, 3, 8, 35, 6, 28),
(2433, '2016-08-28', 2016, 3, 8, 35, 0, 29),
(2434, '2016-08-29', 2016, 3, 8, 35, 1, 30),
(2435, '2016-08-30', 2016, 3, 8, 35, 2, 31),
(2436, '2016-08-31', 2016, 3, 9, 35, 3, 1),
(2437, '2016-09-01', 2016, 3, 9, 35, 4, 2),
(2438, '2016-09-02', 2016, 3, 9, 35, 5, 3),
(2439, '2016-09-03', 2016, 3, 9, 36, 6, 4),
(2440, '2016-09-04', 2016, 3, 9, 36, 0, 5),
(2441, '2016-09-05', 2016, 3, 9, 36, 1, 6),
(2442, '2016-09-06', 2016, 3, 9, 36, 2, 7),
(2443, '2016-09-07', 2016, 3, 9, 36, 3, 8),
(2444, '2016-09-08', 2016, 3, 9, 36, 4, 9),
(2445, '2016-09-09', 2016, 3, 9, 36, 5, 10),
(2446, '2016-09-10', 2016, 3, 9, 37, 6, 11),
(2447, '2016-09-11', 2016, 3, 9, 37, 0, 12),
(2448, '2016-09-12', 2016, 3, 9, 37, 1, 13),
(2449, '2016-09-13', 2016, 3, 9, 37, 2, 14),
(2450, '2016-09-14', 2016, 3, 9, 37, 3, 15),
(2451, '2016-09-15', 2016, 3, 9, 37, 4, 16),
(2452, '2016-09-16', 2016, 3, 9, 37, 5, 17),
(2453, '2016-09-17', 2016, 3, 9, 38, 6, 18),
(2454, '2016-09-18', 2016, 3, 9, 38, 0, 19),
(2455, '2016-09-19', 2016, 3, 9, 38, 1, 20),
(2456, '2016-09-20', 2016, 3, 9, 38, 2, 21),
(2457, '2016-09-21', 2016, 3, 9, 38, 3, 22),
(2458, '2016-09-22', 2016, 3, 9, 38, 4, 23),
(2459, '2016-09-23', 2016, 3, 9, 38, 5, 24),
(2460, '2016-09-24', 2016, 3, 9, 39, 6, 25),
(2461, '2016-09-25', 2016, 3, 9, 39, 0, 26),
(2462, '2016-09-26', 2016, 3, 9, 39, 1, 27),
(2463, '2016-09-27', 2016, 3, 9, 39, 2, 28),
(2464, '2016-09-28', 2016, 3, 9, 39, 3, 29),
(2465, '2016-09-29', 2016, 3, 9, 39, 4, 30),
(2466, '2016-09-30', 2016, 4, 10, 39, 5, 1),
(2467, '2016-10-01', 2016, 4, 10, 40, 6, 2),
(2468, '2016-10-02', 2016, 4, 10, 40, 0, 3),
(2469, '2016-10-03', 2016, 4, 10, 40, 1, 4),
(2470, '2016-10-04', 2016, 4, 10, 40, 2, 5),
(2471, '2016-10-05', 2016, 4, 10, 40, 3, 6),
(2472, '2016-10-06', 2016, 4, 10, 40, 4, 7),
(2473, '2016-10-07', 2016, 4, 10, 40, 5, 8),
(2474, '2016-10-08', 2016, 4, 10, 41, 6, 9),
(2475, '2016-10-09', 2016, 4, 10, 41, 0, 10),
(2476, '2016-10-10', 2016, 4, 10, 41, 1, 11),
(2477, '2016-10-11', 2016, 4, 10, 41, 2, 12),
(2478, '2016-10-12', 2016, 4, 10, 41, 3, 13),
(2479, '2016-10-13', 2016, 4, 10, 41, 4, 14),
(2480, '2016-10-14', 2016, 4, 10, 41, 5, 15),
(2481, '2016-10-15', 2016, 4, 10, 42, 6, 16),
(2482, '2016-10-16', 2016, 4, 10, 42, 0, 17),
(2483, '2016-10-17', 2016, 4, 10, 42, 1, 18),
(2484, '2016-10-18', 2016, 4, 10, 42, 2, 19),
(2485, '2016-10-19', 2016, 4, 10, 42, 3, 20),
(2486, '2016-10-20', 2016, 4, 10, 42, 4, 21),
(2487, '2016-10-21', 2016, 4, 10, 42, 5, 22),
(2488, '2016-10-22', 2016, 4, 10, 43, 6, 23),
(2489, '2016-10-23', 2016, 4, 10, 43, 0, 24),
(2490, '2016-10-24', 2016, 4, 10, 43, 1, 25),
(2491, '2016-10-25', 2016, 4, 10, 43, 2, 26),
(2492, '2016-10-26', 2016, 4, 10, 43, 3, 27),
(2493, '2016-10-27', 2016, 4, 10, 43, 4, 28),
(2494, '2016-10-28', 2016, 4, 10, 43, 5, 29),
(2495, '2016-10-29', 2016, 4, 10, 44, 6, 30),
(2496, '2016-10-30', 2016, 4, 10, 44, 0, 31),
(2497, '2016-10-31', 2016, 4, 11, 44, 1, 1),
(2498, '2016-11-01', 2016, 4, 11, 44, 2, 2),
(2499, '2016-11-02', 2016, 4, 11, 44, 3, 3),
(2500, '2016-11-03', 2016, 4, 11, 44, 4, 4),
(2501, '2016-11-04', 2016, 4, 11, 44, 5, 5),
(2502, '2016-11-05', 2016, 4, 11, 45, 6, 6),
(2503, '2016-11-06', 2016, 4, 11, 45, 0, 7),
(2504, '2016-11-07', 2016, 4, 11, 45, 1, 8),
(2505, '2016-11-08', 2016, 4, 11, 45, 2, 9),
(2506, '2016-11-09', 2016, 4, 11, 45, 3, 10),
(2507, '2016-11-10', 2016, 4, 11, 45, 4, 11),
(2508, '2016-11-11', 2016, 4, 11, 45, 5, 12),
(2509, '2016-11-12', 2016, 4, 11, 46, 6, 13),
(2510, '2016-11-13', 2016, 4, 11, 46, 0, 14),
(2511, '2016-11-14', 2016, 4, 11, 46, 1, 15),
(2512, '2016-11-15', 2016, 4, 11, 46, 2, 16),
(2513, '2016-11-16', 2016, 4, 11, 46, 3, 17),
(2514, '2016-11-17', 2016, 4, 11, 46, 4, 18),
(2515, '2016-11-18', 2016, 4, 11, 46, 5, 19),
(2516, '2016-11-19', 2016, 4, 11, 47, 6, 20),
(2517, '2016-11-20', 2016, 4, 11, 47, 0, 21),
(2518, '2016-11-21', 2016, 4, 11, 47, 1, 22),
(2519, '2016-11-22', 2016, 4, 11, 47, 2, 23),
(2520, '2016-11-23', 2016, 4, 11, 47, 3, 24),
(2521, '2016-11-24', 2016, 4, 11, 47, 4, 25),
(2522, '2016-11-25', 2016, 4, 11, 47, 5, 26),
(2523, '2016-11-26', 2016, 4, 11, 48, 6, 27),
(2524, '2016-11-27', 2016, 4, 11, 48, 0, 28),
(2525, '2016-11-28', 2016, 4, 11, 48, 1, 29),
(2526, '2016-11-29', 2016, 4, 11, 48, 2, 30),
(2527, '2016-11-30', 2016, 4, 12, 48, 3, 1),
(2528, '2016-12-01', 2016, 4, 12, 48, 4, 2),
(2529, '2016-12-02', 2016, 4, 12, 48, 5, 3),
(2530, '2016-12-03', 2016, 4, 12, 49, 6, 4),
(2531, '2016-12-04', 2016, 4, 12, 49, 0, 5),
(2532, '2016-12-05', 2016, 4, 12, 49, 1, 6),
(2533, '2016-12-06', 2016, 4, 12, 49, 2, 7),
(2534, '2016-12-07', 2016, 4, 12, 49, 3, 8),
(2535, '2016-12-08', 2016, 4, 12, 49, 4, 9),
(2536, '2016-12-09', 2016, 4, 12, 49, 5, 10),
(2537, '2016-12-10', 2016, 4, 12, 50, 6, 11),
(2538, '2016-12-11', 2016, 4, 12, 50, 0, 12),
(2539, '2016-12-12', 2016, 4, 12, 50, 1, 13),
(2540, '2016-12-13', 2016, 4, 12, 50, 2, 14),
(2541, '2016-12-14', 2016, 4, 12, 50, 3, 15),
(2542, '2016-12-15', 2016, 4, 12, 50, 4, 16),
(2543, '2016-12-16', 2016, 4, 12, 50, 5, 17),
(2544, '2016-12-17', 2016, 4, 12, 51, 6, 18),
(2545, '2016-12-18', 2016, 4, 12, 51, 0, 19),
(2546, '2016-12-19', 2016, 4, 12, 51, 1, 20),
(2547, '2016-12-20', 2016, 4, 12, 51, 2, 21),
(2548, '2016-12-21', 2016, 4, 12, 51, 3, 22),
(2549, '2016-12-22', 2016, 4, 12, 51, 4, 23),
(2550, '2016-12-23', 2016, 4, 12, 51, 5, 24),
(2551, '2016-12-24', 2016, 4, 12, 52, 6, 25),
(2552, '2016-12-25', 2016, 4, 12, 52, 0, 26),
(2553, '2016-12-26', 2016, 4, 12, 52, 1, 27),
(2554, '2016-12-27', 2016, 4, 12, 52, 2, 28),
(2555, '2016-12-28', 2016, 4, 12, 52, 3, 29),
(2556, '2016-12-29', 2016, 4, 12, 52, 4, 30),
(2557, '2016-12-30', 2016, 4, 12, 52, 5, 31),
(2558, '2016-12-31', 2017, 1, 1, 1, 6, 1),
(2559, '2017-01-01', 2017, 1, 1, 1, 0, 2),
(2560, '2017-01-02', 2017, 1, 1, 1, 1, 3),
(2561, '2017-01-03', 2017, 1, 1, 1, 2, 4),
(2562, '2017-01-04', 2017, 1, 1, 1, 3, 5),
(2563, '2017-01-05', 2017, 1, 1, 1, 4, 6),
(2564, '2017-01-06', 2017, 1, 1, 1, 5, 7),
(2565, '2017-01-07', 2017, 1, 1, 2, 6, 8),
(2566, '2017-01-08', 2017, 1, 1, 2, 0, 9),
(2567, '2017-01-09', 2017, 1, 1, 2, 1, 10),
(2568, '2017-01-10', 2017, 1, 1, 2, 2, 11),
(2569, '2017-01-11', 2017, 1, 1, 2, 3, 12),
(2570, '2017-01-12', 2017, 1, 1, 2, 4, 13),
(2571, '2017-01-13', 2017, 1, 1, 2, 5, 14),
(2572, '2017-01-14', 2017, 1, 1, 3, 6, 15),
(2573, '2017-01-15', 2017, 1, 1, 3, 0, 16),
(2574, '2017-01-16', 2017, 1, 1, 3, 1, 17),
(2575, '2017-01-17', 2017, 1, 1, 3, 2, 18),
(2576, '2017-01-18', 2017, 1, 1, 3, 3, 19),
(2577, '2017-01-19', 2017, 1, 1, 3, 4, 20),
(2578, '2017-01-20', 2017, 1, 1, 3, 5, 21),
(2579, '2017-01-21', 2017, 1, 1, 4, 6, 22),
(2580, '2017-01-22', 2017, 1, 1, 4, 0, 23),
(2581, '2017-01-23', 2017, 1, 1, 4, 1, 24),
(2582, '2017-01-24', 2017, 1, 1, 4, 2, 25),
(2583, '2017-01-25', 2017, 1, 1, 4, 3, 26),
(2584, '2017-01-26', 2017, 1, 1, 4, 4, 27),
(2585, '2017-01-27', 2017, 1, 1, 4, 5, 28),
(2586, '2017-01-28', 2017, 1, 1, 5, 6, 29),
(2587, '2017-01-29', 2017, 1, 1, 5, 0, 30),
(2588, '2017-01-30', 2017, 1, 1, 5, 1, 31),
(2589, '2017-01-31', 2017, 1, 2, 5, 2, 1),
(2590, '2017-02-01', 2017, 1, 2, 5, 3, 2),
(2591, '2017-02-02', 2017, 1, 2, 5, 4, 3),
(2592, '2017-02-03', 2017, 1, 2, 5, 5, 4),
(2593, '2017-02-04', 2017, 1, 2, 6, 6, 5),
(2594, '2017-02-05', 2017, 1, 2, 6, 0, 6),
(2595, '2017-02-06', 2017, 1, 2, 6, 1, 7),
(2596, '2017-02-07', 2017, 1, 2, 6, 2, 8),
(2597, '2017-02-08', 2017, 1, 2, 6, 3, 9),
(2598, '2017-02-09', 2017, 1, 2, 6, 4, 10),
(2599, '2017-02-10', 2017, 1, 2, 6, 5, 11),
(2600, '2017-02-11', 2017, 1, 2, 7, 6, 12),
(2601, '2017-02-12', 2017, 1, 2, 7, 0, 13),
(2602, '2017-02-13', 2017, 1, 2, 7, 1, 14),
(2603, '2017-02-14', 2017, 1, 2, 7, 2, 15),
(2604, '2017-02-15', 2017, 1, 2, 7, 3, 16),
(2605, '2017-02-16', 2017, 1, 2, 7, 4, 17),
(2606, '2017-02-17', 2017, 1, 2, 7, 5, 18),
(2607, '2017-02-18', 2017, 1, 2, 8, 6, 19),
(2608, '2017-02-19', 2017, 1, 2, 8, 0, 20),
(2609, '2017-02-20', 2017, 1, 2, 8, 1, 21),
(2610, '2017-02-21', 2017, 1, 2, 8, 2, 22),
(2611, '2017-02-22', 2017, 1, 2, 8, 3, 23),
(2612, '2017-02-23', 2017, 1, 2, 8, 4, 24),
(2613, '2017-02-24', 2017, 1, 2, 8, 5, 25),
(2614, '2017-02-25', 2017, 1, 2, 9, 6, 26),
(2615, '2017-02-26', 2017, 1, 2, 9, 0, 27),
(2616, '2017-02-27', 2017, 1, 2, 9, 1, 28),
(2617, '2017-02-28', 2017, 1, 3, 9, 2, 1),
(2618, '2017-03-01', 2017, 1, 3, 9, 3, 2),
(2619, '2017-03-02', 2017, 1, 3, 9, 4, 3),
(2620, '2017-03-03', 2017, 1, 3, 9, 5, 4),
(2621, '2017-03-04', 2017, 1, 3, 10, 6, 5),
(2622, '2017-03-05', 2017, 1, 3, 10, 0, 6),
(2623, '2017-03-06', 2017, 1, 3, 10, 1, 7),
(2624, '2017-03-07', 2017, 1, 3, 10, 2, 8),
(2625, '2017-03-08', 2017, 1, 3, 10, 3, 9),
(2626, '2017-03-09', 2017, 1, 3, 10, 4, 10),
(2627, '2017-03-10', 2017, 1, 3, 10, 5, 11),
(2628, '2017-03-11', 2017, 1, 3, 11, 6, 12),
(2629, '2017-03-12', 2017, 1, 3, 11, 0, 13),
(2630, '2017-03-13', 2017, 1, 3, 11, 1, 14),
(2631, '2017-03-14', 2017, 1, 3, 11, 2, 15),
(2632, '2017-03-15', 2017, 1, 3, 11, 3, 16),
(2633, '2017-03-16', 2017, 1, 3, 11, 4, 17),
(2634, '2017-03-17', 2017, 1, 3, 11, 5, 18),
(2635, '2017-03-18', 2017, 1, 3, 12, 6, 19),
(2636, '2017-03-19', 2017, 1, 3, 12, 0, 20),
(2637, '2017-03-20', 2017, 1, 3, 12, 1, 21),
(2638, '2017-03-21', 2017, 1, 3, 12, 2, 22),
(2639, '2017-03-22', 2017, 1, 3, 12, 3, 23),
(2640, '2017-03-23', 2017, 1, 3, 12, 4, 24),
(2641, '2017-03-24', 2017, 1, 3, 12, 5, 25),
(2642, '2017-03-25', 2017, 1, 3, 13, 6, 26),
(2643, '2017-03-26', 2017, 1, 3, 13, 0, 27),
(2644, '2017-03-27', 2017, 1, 3, 13, 1, 28),
(2645, '2017-03-28', 2017, 1, 3, 13, 2, 29),
(2646, '2017-03-29', 2017, 1, 3, 13, 3, 30),
(2647, '2017-03-30', 2017, 1, 3, 13, 4, 31),
(2648, '2017-03-31', 2017, 2, 4, 13, 5, 1),
(2649, '2017-04-01', 2017, 2, 4, 14, 6, 2),
(2650, '2017-04-02', 2017, 2, 4, 14, 0, 3),
(2651, '2017-04-03', 2017, 2, 4, 14, 1, 4),
(2652, '2017-04-04', 2017, 2, 4, 14, 2, 5),
(2653, '2017-04-05', 2017, 2, 4, 14, 3, 6),
(2654, '2017-04-06', 2017, 2, 4, 14, 4, 7),
(2655, '2017-04-07', 2017, 2, 4, 14, 5, 8),
(2656, '2017-04-08', 2017, 2, 4, 15, 6, 9),
(2657, '2017-04-09', 2017, 2, 4, 15, 0, 10),
(2658, '2017-04-10', 2017, 2, 4, 15, 1, 11),
(2659, '2017-04-11', 2017, 2, 4, 15, 2, 12),
(2660, '2017-04-12', 2017, 2, 4, 15, 3, 13),
(2661, '2017-04-13', 2017, 2, 4, 15, 4, 14),
(2662, '2017-04-14', 2017, 2, 4, 15, 5, 15),
(2663, '2017-04-15', 2017, 2, 4, 16, 6, 16),
(2664, '2017-04-16', 2017, 2, 4, 16, 0, 17),
(2665, '2017-04-17', 2017, 2, 4, 16, 1, 18),
(2666, '2017-04-18', 2017, 2, 4, 16, 2, 19),
(2667, '2017-04-19', 2017, 2, 4, 16, 3, 20),
(2668, '2017-04-20', 2017, 2, 4, 16, 4, 21),
(2669, '2017-04-21', 2017, 2, 4, 16, 5, 22),
(2670, '2017-04-22', 2017, 2, 4, 17, 6, 23),
(2671, '2017-04-23', 2017, 2, 4, 17, 0, 24),
(2672, '2017-04-24', 2017, 2, 4, 17, 1, 25),
(2673, '2017-04-25', 2017, 2, 4, 17, 2, 26),
(2674, '2017-04-26', 2017, 2, 4, 17, 3, 27),
(2675, '2017-04-27', 2017, 2, 4, 17, 4, 28),
(2676, '2017-04-28', 2017, 2, 4, 17, 5, 29),
(2677, '2017-04-29', 2017, 2, 4, 18, 6, 30),
(2678, '2017-04-30', 2017, 2, 5, 18, 0, 1),
(2679, '2017-05-01', 2017, 2, 5, 18, 1, 2),
(2680, '2017-05-02', 2017, 2, 5, 18, 2, 3),
(2681, '2017-05-03', 2017, 2, 5, 18, 3, 4),
(2682, '2017-05-04', 2017, 2, 5, 18, 4, 5),
(2683, '2017-05-05', 2017, 2, 5, 18, 5, 6),
(2684, '2017-05-06', 2017, 2, 5, 19, 6, 7),
(2685, '2017-05-07', 2017, 2, 5, 19, 0, 8),
(2686, '2017-05-08', 2017, 2, 5, 19, 1, 9),
(2687, '2017-05-09', 2017, 2, 5, 19, 2, 10),
(2688, '2017-05-10', 2017, 2, 5, 19, 3, 11),
(2689, '2017-05-11', 2017, 2, 5, 19, 4, 12),
(2690, '2017-05-12', 2017, 2, 5, 19, 5, 13),
(2691, '2017-05-13', 2017, 2, 5, 20, 6, 14),
(2692, '2017-05-14', 2017, 2, 5, 20, 0, 15),
(2693, '2017-05-15', 2017, 2, 5, 20, 1, 16),
(2694, '2017-05-16', 2017, 2, 5, 20, 2, 17),
(2695, '2017-05-17', 2017, 2, 5, 20, 3, 18),
(2696, '2017-05-18', 2017, 2, 5, 20, 4, 19),
(2697, '2017-05-19', 2017, 2, 5, 20, 5, 20),
(2698, '2017-05-20', 2017, 2, 5, 21, 6, 21),
(2699, '2017-05-21', 2017, 2, 5, 21, 0, 22),
(2700, '2017-05-22', 2017, 2, 5, 21, 1, 23),
(2701, '2017-05-23', 2017, 2, 5, 21, 2, 24),
(2702, '2017-05-24', 2017, 2, 5, 21, 3, 25),
(2703, '2017-05-25', 2017, 2, 5, 21, 4, 26),
(2704, '2017-05-26', 2017, 2, 5, 21, 5, 27),
(2705, '2017-05-27', 2017, 2, 5, 22, 6, 28),
(2706, '2017-05-28', 2017, 2, 5, 22, 0, 29),
(2707, '2017-05-29', 2017, 2, 5, 22, 1, 30),
(2708, '2017-05-30', 2017, 2, 5, 22, 2, 31),
(2709, '2017-05-31', 2017, 2, 6, 22, 3, 1),
(2710, '2017-06-01', 2017, 2, 6, 22, 4, 2),
(2711, '2017-06-02', 2017, 2, 6, 22, 5, 3),
(2712, '2017-06-03', 2017, 2, 6, 23, 6, 4),
(2713, '2017-06-04', 2017, 2, 6, 23, 0, 5),
(2714, '2017-06-05', 2017, 2, 6, 23, 1, 6),
(2715, '2017-06-06', 2017, 2, 6, 23, 2, 7),
(2716, '2017-06-07', 2017, 2, 6, 23, 3, 8),
(2717, '2017-06-08', 2017, 2, 6, 23, 4, 9),
(2718, '2017-06-09', 2017, 2, 6, 23, 5, 10),
(2719, '2017-06-10', 2017, 2, 6, 24, 6, 11),
(2720, '2017-06-11', 2017, 2, 6, 24, 0, 12),
(2721, '2017-06-12', 2017, 2, 6, 24, 1, 13),
(2722, '2017-06-13', 2017, 2, 6, 24, 2, 14),
(2723, '2017-06-14', 2017, 2, 6, 24, 3, 15),
(2724, '2017-06-15', 2017, 2, 6, 24, 4, 16),
(2725, '2017-06-16', 2017, 2, 6, 24, 5, 17),
(2726, '2017-06-17', 2017, 2, 6, 25, 6, 18),
(2727, '2017-06-18', 2017, 2, 6, 25, 0, 19),
(2728, '2017-06-19', 2017, 2, 6, 25, 1, 20),
(2729, '2017-06-20', 2017, 2, 6, 25, 2, 21),
(2730, '2017-06-21', 2017, 2, 6, 25, 3, 22),
(2731, '2017-06-22', 2017, 2, 6, 25, 4, 23),
(2732, '2017-06-23', 2017, 2, 6, 25, 5, 24),
(2733, '2017-06-24', 2017, 2, 6, 26, 6, 25),
(2734, '2017-06-25', 2017, 2, 6, 26, 0, 26),
(2735, '2017-06-26', 2017, 2, 6, 26, 1, 27),
(2736, '2017-06-27', 2017, 2, 6, 26, 2, 28),
(2737, '2017-06-28', 2017, 2, 6, 26, 3, 29),
(2738, '2017-06-29', 2017, 2, 6, 26, 4, 30),
(2739, '2017-06-30', 2017, 3, 7, 26, 5, 1),
(2740, '2017-07-01', 2017, 3, 7, 27, 6, 2),
(2741, '2017-07-02', 2017, 3, 7, 27, 0, 3),
(2742, '2017-07-03', 2017, 3, 7, 27, 1, 4),
(2743, '2017-07-04', 2017, 3, 7, 27, 2, 5),
(2744, '2017-07-05', 2017, 3, 7, 27, 3, 6),
(2745, '2017-07-06', 2017, 3, 7, 27, 4, 7),
(2746, '2017-07-07', 2017, 3, 7, 27, 5, 8),
(2747, '2017-07-08', 2017, 3, 7, 28, 6, 9),
(2748, '2017-07-09', 2017, 3, 7, 28, 0, 10),
(2749, '2017-07-10', 2017, 3, 7, 28, 1, 11),
(2750, '2017-07-11', 2017, 3, 7, 28, 2, 12),
(2751, '2017-07-12', 2017, 3, 7, 28, 3, 13),
(2752, '2017-07-13', 2017, 3, 7, 28, 4, 14),
(2753, '2017-07-14', 2017, 3, 7, 28, 5, 15),
(2754, '2017-07-15', 2017, 3, 7, 29, 6, 16),
(2755, '2017-07-16', 2017, 3, 7, 29, 0, 17),
(2756, '2017-07-17', 2017, 3, 7, 29, 1, 18),
(2757, '2017-07-18', 2017, 3, 7, 29, 2, 19),
(2758, '2017-07-19', 2017, 3, 7, 29, 3, 20),
(2759, '2017-07-20', 2017, 3, 7, 29, 4, 21),
(2760, '2017-07-21', 2017, 3, 7, 29, 5, 22),
(2761, '2017-07-22', 2017, 3, 7, 30, 6, 23),
(2762, '2017-07-23', 2017, 3, 7, 30, 0, 24),
(2763, '2017-07-24', 2017, 3, 7, 30, 1, 25),
(2764, '2017-07-25', 2017, 3, 7, 30, 2, 26),
(2765, '2017-07-26', 2017, 3, 7, 30, 3, 27),
(2766, '2017-07-27', 2017, 3, 7, 30, 4, 28),
(2767, '2017-07-28', 2017, 3, 7, 30, 5, 29),
(2768, '2017-07-29', 2017, 3, 7, 31, 6, 30),
(2769, '2017-07-30', 2017, 3, 7, 31, 0, 31),
(2770, '2017-07-31', 2017, 3, 8, 31, 1, 1),
(2771, '2017-08-01', 2017, 3, 8, 31, 2, 2),
(2772, '2017-08-02', 2017, 3, 8, 31, 3, 3),
(2773, '2017-08-03', 2017, 3, 8, 31, 4, 4),
(2774, '2017-08-04', 2017, 3, 8, 31, 5, 5),
(2775, '2017-08-05', 2017, 3, 8, 32, 6, 6),
(2776, '2017-08-06', 2017, 3, 8, 32, 0, 7),
(2777, '2017-08-07', 2017, 3, 8, 32, 1, 8),
(2778, '2017-08-08', 2017, 3, 8, 32, 2, 9),
(2779, '2017-08-09', 2017, 3, 8, 32, 3, 10),
(2780, '2017-08-10', 2017, 3, 8, 32, 4, 11),
(2781, '2017-08-11', 2017, 3, 8, 32, 5, 12),
(2782, '2017-08-12', 2017, 3, 8, 33, 6, 13),
(2783, '2017-08-13', 2017, 3, 8, 33, 0, 14),
(2784, '2017-08-14', 2017, 3, 8, 33, 1, 15),
(2785, '2017-08-15', 2017, 3, 8, 33, 2, 16),
(2786, '2017-08-16', 2017, 3, 8, 33, 3, 17),
(2787, '2017-08-17', 2017, 3, 8, 33, 4, 18),
(2788, '2017-08-18', 2017, 3, 8, 33, 5, 19),
(2789, '2017-08-19', 2017, 3, 8, 34, 6, 20),
(2790, '2017-08-20', 2017, 3, 8, 34, 0, 21),
(2791, '2017-08-21', 2017, 3, 8, 34, 1, 22),
(2792, '2017-08-22', 2017, 3, 8, 34, 2, 23),
(2793, '2017-08-23', 2017, 3, 8, 34, 3, 24),
(2794, '2017-08-24', 2017, 3, 8, 34, 4, 25),
(2795, '2017-08-25', 2017, 3, 8, 34, 5, 26),
(2796, '2017-08-26', 2017, 3, 8, 35, 6, 27),
(2797, '2017-08-27', 2017, 3, 8, 35, 0, 28),
(2798, '2017-08-28', 2017, 3, 8, 35, 1, 29),
(2799, '2017-08-29', 2017, 3, 8, 35, 2, 30),
(2800, '2017-08-30', 2017, 3, 8, 35, 3, 31),
(2801, '2017-08-31', 2017, 3, 9, 35, 4, 1),
(2802, '2017-09-01', 2017, 3, 9, 35, 5, 2),
(2803, '2017-09-02', 2017, 3, 9, 36, 6, 3),
(2804, '2017-09-03', 2017, 3, 9, 36, 0, 4),
(2805, '2017-09-04', 2017, 3, 9, 36, 1, 5),
(2806, '2017-09-05', 2017, 3, 9, 36, 2, 6),
(2807, '2017-09-06', 2017, 3, 9, 36, 3, 7),
(2808, '2017-09-07', 2017, 3, 9, 36, 4, 8),
(2809, '2017-09-08', 2017, 3, 9, 36, 5, 9),
(2810, '2017-09-09', 2017, 3, 9, 37, 6, 10),
(2811, '2017-09-10', 2017, 3, 9, 37, 0, 11),
(2812, '2017-09-11', 2017, 3, 9, 37, 1, 12),
(2813, '2017-09-12', 2017, 3, 9, 37, 2, 13),
(2814, '2017-09-13', 2017, 3, 9, 37, 3, 14),
(2815, '2017-09-14', 2017, 3, 9, 37, 4, 15),
(2816, '2017-09-15', 2017, 3, 9, 37, 5, 16),
(2817, '2017-09-16', 2017, 3, 9, 38, 6, 17),
(2818, '2017-09-17', 2017, 3, 9, 38, 0, 18),
(2819, '2017-09-18', 2017, 3, 9, 38, 1, 19),
(2820, '2017-09-19', 2017, 3, 9, 38, 2, 20),
(2821, '2017-09-20', 2017, 3, 9, 38, 3, 21),
(2822, '2017-09-21', 2017, 3, 9, 38, 4, 22),
(2823, '2017-09-22', 2017, 3, 9, 38, 5, 23),
(2824, '2017-09-23', 2017, 3, 9, 39, 6, 24),
(2825, '2017-09-24', 2017, 3, 9, 39, 0, 25),
(2826, '2017-09-25', 2017, 3, 9, 39, 1, 26),
(2827, '2017-09-26', 2017, 3, 9, 39, 2, 27),
(2828, '2017-09-27', 2017, 3, 9, 39, 3, 28),
(2829, '2017-09-28', 2017, 3, 9, 39, 4, 29),
(2830, '2017-09-29', 2017, 3, 9, 39, 5, 30),
(2831, '2017-09-30', 2017, 4, 10, 40, 6, 1),
(2832, '2017-10-01', 2017, 4, 10, 40, 0, 2),
(2833, '2017-10-02', 2017, 4, 10, 40, 1, 3),
(2834, '2017-10-03', 2017, 4, 10, 40, 2, 4),
(2835, '2017-10-04', 2017, 4, 10, 40, 3, 5),
(2836, '2017-10-05', 2017, 4, 10, 40, 4, 6),
(2837, '2017-10-06', 2017, 4, 10, 40, 5, 7),
(2838, '2017-10-07', 2017, 4, 10, 41, 6, 8),
(2839, '2017-10-08', 2017, 4, 10, 41, 0, 9),
(2840, '2017-10-09', 2017, 4, 10, 41, 1, 10),
(2841, '2017-10-10', 2017, 4, 10, 41, 2, 11),
(2842, '2017-10-11', 2017, 4, 10, 41, 3, 12),
(2843, '2017-10-12', 2017, 4, 10, 41, 4, 13),
(2844, '2017-10-13', 2017, 4, 10, 41, 5, 14),
(2845, '2017-10-14', 2017, 4, 10, 42, 6, 15),
(2846, '2017-10-15', 2017, 4, 10, 42, 0, 16),
(2847, '2017-10-16', 2017, 4, 10, 42, 1, 17),
(2848, '2017-10-17', 2017, 4, 10, 42, 2, 18),
(2849, '2017-10-18', 2017, 4, 10, 42, 3, 19),
(2850, '2017-10-19', 2017, 4, 10, 42, 4, 20),
(2851, '2017-10-20', 2017, 4, 10, 42, 5, 21),
(2852, '2017-10-21', 2017, 4, 10, 43, 6, 22),
(2853, '2017-10-22', 2017, 4, 10, 43, 0, 23),
(2854, '2017-10-23', 2017, 4, 10, 43, 1, 24),
(2855, '2017-10-24', 2017, 4, 10, 43, 2, 25),
(2856, '2017-10-25', 2017, 4, 10, 43, 3, 26),
(2857, '2017-10-26', 2017, 4, 10, 43, 4, 27),
(2858, '2017-10-27', 2017, 4, 10, 43, 5, 28),
(2859, '2017-10-28', 2017, 4, 10, 44, 6, 29),
(2860, '2017-10-29', 2017, 4, 10, 44, 0, 30),
(2861, '2017-10-30', 2017, 4, 10, 44, 1, 31),
(2862, '2017-10-31', 2017, 4, 11, 44, 2, 1),
(2863, '2017-11-01', 2017, 4, 11, 44, 3, 2),
(2864, '2017-11-02', 2017, 4, 11, 44, 4, 3),
(2865, '2017-11-03', 2017, 4, 11, 44, 5, 4),
(2866, '2017-11-04', 2017, 4, 11, 45, 6, 5),
(2867, '2017-11-05', 2017, 4, 11, 45, 0, 6),
(2868, '2017-11-06', 2017, 4, 11, 45, 1, 7),
(2869, '2017-11-07', 2017, 4, 11, 45, 2, 8),
(2870, '2017-11-08', 2017, 4, 11, 45, 3, 9),
(2871, '2017-11-09', 2017, 4, 11, 45, 4, 10),
(2872, '2017-11-10', 2017, 4, 11, 45, 5, 11),
(2873, '2017-11-11', 2017, 4, 11, 46, 6, 12),
(2874, '2017-11-12', 2017, 4, 11, 46, 0, 13),
(2875, '2017-11-13', 2017, 4, 11, 46, 1, 14),
(2876, '2017-11-14', 2017, 4, 11, 46, 2, 15),
(2877, '2017-11-15', 2017, 4, 11, 46, 3, 16),
(2878, '2017-11-16', 2017, 4, 11, 46, 4, 17),
(2879, '2017-11-17', 2017, 4, 11, 46, 5, 18),
(2880, '2017-11-18', 2017, 4, 11, 47, 6, 19),
(2881, '2017-11-19', 2017, 4, 11, 47, 0, 20),
(2882, '2017-11-20', 2017, 4, 11, 47, 1, 21),
(2883, '2017-11-21', 2017, 4, 11, 47, 2, 22),
(2884, '2017-11-22', 2017, 4, 11, 47, 3, 23),
(2885, '2017-11-23', 2017, 4, 11, 47, 4, 24),
(2886, '2017-11-24', 2017, 4, 11, 47, 5, 25),
(2887, '2017-11-25', 2017, 4, 11, 48, 6, 26),
(2888, '2017-11-26', 2017, 4, 11, 48, 0, 27),
(2889, '2017-11-27', 2017, 4, 11, 48, 1, 28),
(2890, '2017-11-28', 2017, 4, 11, 48, 2, 29),
(2891, '2017-11-29', 2017, 4, 11, 48, 3, 30),
(2892, '2017-11-30', 2017, 4, 12, 48, 4, 1),
(2893, '2017-12-01', 2017, 4, 12, 48, 5, 2),
(2894, '2017-12-02', 2017, 4, 12, 49, 6, 3),
(2895, '2017-12-03', 2017, 4, 12, 49, 0, 4),
(2896, '2017-12-04', 2017, 4, 12, 49, 1, 5),
(2897, '2017-12-05', 2017, 4, 12, 49, 2, 6),
(2898, '2017-12-06', 2017, 4, 12, 49, 3, 7),
(2899, '2017-12-07', 2017, 4, 12, 49, 4, 8),
(2900, '2017-12-08', 2017, 4, 12, 49, 5, 9),
(2901, '2017-12-09', 2017, 4, 12, 50, 6, 10),
(2902, '2017-12-10', 2017, 4, 12, 50, 0, 11),
(2903, '2017-12-11', 2017, 4, 12, 50, 1, 12),
(2904, '2017-12-12', 2017, 4, 12, 50, 2, 13),
(2905, '2017-12-13', 2017, 4, 12, 50, 3, 14),
(2906, '2017-12-14', 2017, 4, 12, 50, 4, 15),
(2907, '2017-12-15', 2017, 4, 12, 50, 5, 16),
(2908, '2017-12-16', 2017, 4, 12, 51, 6, 17),
(2909, '2017-12-17', 2017, 4, 12, 51, 0, 18),
(2910, '2017-12-18', 2017, 4, 12, 51, 1, 19),
(2911, '2017-12-19', 2017, 4, 12, 51, 2, 20),
(2912, '2017-12-20', 2017, 4, 12, 51, 3, 21),
(2913, '2017-12-21', 2017, 4, 12, 51, 4, 22),
(2914, '2017-12-22', 2017, 4, 12, 51, 5, 23),
(2915, '2017-12-23', 2017, 4, 12, 52, 6, 24),
(2916, '2017-12-24', 2017, 4, 12, 52, 0, 25),
(2917, '2017-12-25', 2017, 4, 12, 52, 1, 26),
(2918, '2017-12-26', 2017, 4, 12, 52, 2, 27),
(2919, '2017-12-27', 2017, 4, 12, 52, 3, 28),
(2920, '2017-12-28', 2017, 4, 12, 52, 4, 29),
(2921, '2017-12-29', 2017, 4, 12, 52, 5, 30),
(2922, '2017-12-30', 2017, 4, 12, 53, 6, 31),
(2923, '2017-12-31', 2018, 1, 1, 0, 0, 1),
(2924, '2018-01-01', 2018, 1, 1, 0, 1, 2),
(2925, '2018-01-02', 2018, 1, 1, 0, 2, 3),
(2926, '2018-01-03', 2018, 1, 1, 0, 3, 4),
(2927, '2018-01-04', 2018, 1, 1, 0, 4, 5),
(2928, '2018-01-05', 2018, 1, 1, 0, 5, 6),
(2929, '2018-01-06', 2018, 1, 1, 1, 6, 7),
(2930, '2018-01-07', 2018, 1, 1, 1, 0, 8),
(2931, '2018-01-08', 2018, 1, 1, 1, 1, 9),
(2932, '2018-01-09', 2018, 1, 1, 1, 2, 10),
(2933, '2018-01-10', 2018, 1, 1, 1, 3, 11),
(2934, '2018-01-11', 2018, 1, 1, 1, 4, 12),
(2935, '2018-01-12', 2018, 1, 1, 1, 5, 13),
(2936, '2018-01-13', 2018, 1, 1, 2, 6, 14),
(2937, '2018-01-14', 2018, 1, 1, 2, 0, 15),
(2938, '2018-01-15', 2018, 1, 1, 2, 1, 16),
(2939, '2018-01-16', 2018, 1, 1, 2, 2, 17),
(2940, '2018-01-17', 2018, 1, 1, 2, 3, 18),
(2941, '2018-01-18', 2018, 1, 1, 2, 4, 19),
(2942, '2018-01-19', 2018, 1, 1, 2, 5, 20),
(2943, '2018-01-20', 2018, 1, 1, 3, 6, 21),
(2944, '2018-01-21', 2018, 1, 1, 3, 0, 22),
(2945, '2018-01-22', 2018, 1, 1, 3, 1, 23),
(2946, '2018-01-23', 2018, 1, 1, 3, 2, 24),
(2947, '2018-01-24', 2018, 1, 1, 3, 3, 25),
(2948, '2018-01-25', 2018, 1, 1, 3, 4, 26),
(2949, '2018-01-26', 2018, 1, 1, 3, 5, 27),
(2950, '2018-01-27', 2018, 1, 1, 4, 6, 28),
(2951, '2018-01-28', 2018, 1, 1, 4, 0, 29),
(2952, '2018-01-29', 2018, 1, 1, 4, 1, 30),
(2953, '2018-01-30', 2018, 1, 1, 4, 2, 31),
(2954, '2018-01-31', 2018, 1, 2, 4, 3, 1),
(2955, '2018-02-01', 2018, 1, 2, 4, 4, 2),
(2956, '2018-02-02', 2018, 1, 2, 4, 5, 3),
(2957, '2018-02-03', 2018, 1, 2, 5, 6, 4),
(2958, '2018-02-04', 2018, 1, 2, 5, 0, 5),
(2959, '2018-02-05', 2018, 1, 2, 5, 1, 6),
(2960, '2018-02-06', 2018, 1, 2, 5, 2, 7),
(2961, '2018-02-07', 2018, 1, 2, 5, 3, 8),
(2962, '2018-02-08', 2018, 1, 2, 5, 4, 9),
(2963, '2018-02-09', 2018, 1, 2, 5, 5, 10),
(2964, '2018-02-10', 2018, 1, 2, 6, 6, 11),
(2965, '2018-02-11', 2018, 1, 2, 6, 0, 12),
(2966, '2018-02-12', 2018, 1, 2, 6, 1, 13),
(2967, '2018-02-13', 2018, 1, 2, 6, 2, 14),
(2968, '2018-02-14', 2018, 1, 2, 6, 3, 15),
(2969, '2018-02-15', 2018, 1, 2, 6, 4, 16),
(2970, '2018-02-16', 2018, 1, 2, 6, 5, 17),
(2971, '2018-02-17', 2018, 1, 2, 7, 6, 18),
(2972, '2018-02-18', 2018, 1, 2, 7, 0, 19),
(2973, '2018-02-19', 2018, 1, 2, 7, 1, 20),
(2974, '2018-02-20', 2018, 1, 2, 7, 2, 21),
(2975, '2018-02-21', 2018, 1, 2, 7, 3, 22),
(2976, '2018-02-22', 2018, 1, 2, 7, 4, 23),
(2977, '2018-02-23', 2018, 1, 2, 7, 5, 24),
(2978, '2018-02-24', 2018, 1, 2, 8, 6, 25),
(2979, '2018-02-25', 2018, 1, 2, 8, 0, 26),
(2980, '2018-02-26', 2018, 1, 2, 8, 1, 27),
(2981, '2018-02-27', 2018, 1, 2, 8, 2, 28),
(2982, '2018-02-28', 2018, 1, 3, 8, 3, 1),
(2983, '2018-03-01', 2018, 1, 3, 8, 4, 2),
(2984, '2018-03-02', 2018, 1, 3, 8, 5, 3),
(2985, '2018-03-03', 2018, 1, 3, 9, 6, 4),
(2986, '2018-03-04', 2018, 1, 3, 9, 0, 5),
(2987, '2018-03-05', 2018, 1, 3, 9, 1, 6),
(2988, '2018-03-06', 2018, 1, 3, 9, 2, 7),
(2989, '2018-03-07', 2018, 1, 3, 9, 3, 8),
(2990, '2018-03-08', 2018, 1, 3, 9, 4, 9),
(2991, '2018-03-09', 2018, 1, 3, 9, 5, 10),
(2992, '2018-03-10', 2018, 1, 3, 10, 6, 11),
(2993, '2018-03-11', 2018, 1, 3, 10, 0, 12),
(2994, '2018-03-12', 2018, 1, 3, 10, 1, 13);
INSERT INTO `razor_dim_date` (`date_sk`, `datevalue`, `year`, `quarter`, `month`, `week`, `dayofweek`, `day`) VALUES
(2995, '2018-03-13', 2018, 1, 3, 10, 2, 14),
(2996, '2018-03-14', 2018, 1, 3, 10, 3, 15),
(2997, '2018-03-15', 2018, 1, 3, 10, 4, 16),
(2998, '2018-03-16', 2018, 1, 3, 10, 5, 17),
(2999, '2018-03-17', 2018, 1, 3, 11, 6, 18),
(3000, '2018-03-18', 2018, 1, 3, 11, 0, 19),
(3001, '2018-03-19', 2018, 1, 3, 11, 1, 20),
(3002, '2018-03-20', 2018, 1, 3, 11, 2, 21),
(3003, '2018-03-21', 2018, 1, 3, 11, 3, 22),
(3004, '2018-03-22', 2018, 1, 3, 11, 4, 23),
(3005, '2018-03-23', 2018, 1, 3, 11, 5, 24),
(3006, '2018-03-24', 2018, 1, 3, 12, 6, 25),
(3007, '2018-03-25', 2018, 1, 3, 12, 0, 26),
(3008, '2018-03-26', 2018, 1, 3, 12, 1, 27),
(3009, '2018-03-27', 2018, 1, 3, 12, 2, 28),
(3010, '2018-03-28', 2018, 1, 3, 12, 3, 29),
(3011, '2018-03-29', 2018, 1, 3, 12, 4, 30),
(3012, '2018-03-30', 2018, 1, 3, 12, 5, 31),
(3013, '2018-03-31', 2018, 2, 4, 13, 6, 1),
(3014, '2018-04-01', 2018, 2, 4, 13, 0, 2),
(3015, '2018-04-02', 2018, 2, 4, 13, 1, 3),
(3016, '2018-04-03', 2018, 2, 4, 13, 2, 4),
(3017, '2018-04-04', 2018, 2, 4, 13, 3, 5),
(3018, '2018-04-05', 2018, 2, 4, 13, 4, 6),
(3019, '2018-04-06', 2018, 2, 4, 13, 5, 7),
(3020, '2018-04-07', 2018, 2, 4, 14, 6, 8),
(3021, '2018-04-08', 2018, 2, 4, 14, 0, 9),
(3022, '2018-04-09', 2018, 2, 4, 14, 1, 10),
(3023, '2018-04-10', 2018, 2, 4, 14, 2, 11),
(3024, '2018-04-11', 2018, 2, 4, 14, 3, 12),
(3025, '2018-04-12', 2018, 2, 4, 14, 4, 13),
(3026, '2018-04-13', 2018, 2, 4, 14, 5, 14),
(3027, '2018-04-14', 2018, 2, 4, 15, 6, 15),
(3028, '2018-04-15', 2018, 2, 4, 15, 0, 16),
(3029, '2018-04-16', 2018, 2, 4, 15, 1, 17),
(3030, '2018-04-17', 2018, 2, 4, 15, 2, 18),
(3031, '2018-04-18', 2018, 2, 4, 15, 3, 19),
(3032, '2018-04-19', 2018, 2, 4, 15, 4, 20),
(3033, '2018-04-20', 2018, 2, 4, 15, 5, 21),
(3034, '2018-04-21', 2018, 2, 4, 16, 6, 22),
(3035, '2018-04-22', 2018, 2, 4, 16, 0, 23),
(3036, '2018-04-23', 2018, 2, 4, 16, 1, 24),
(3037, '2018-04-24', 2018, 2, 4, 16, 2, 25),
(3038, '2018-04-25', 2018, 2, 4, 16, 3, 26),
(3039, '2018-04-26', 2018, 2, 4, 16, 4, 27),
(3040, '2018-04-27', 2018, 2, 4, 16, 5, 28),
(3041, '2018-04-28', 2018, 2, 4, 17, 6, 29),
(3042, '2018-04-29', 2018, 2, 4, 17, 0, 30),
(3043, '2018-04-30', 2018, 2, 5, 17, 1, 1),
(3044, '2018-05-01', 2018, 2, 5, 17, 2, 2),
(3045, '2018-05-02', 2018, 2, 5, 17, 3, 3),
(3046, '2018-05-03', 2018, 2, 5, 17, 4, 4),
(3047, '2018-05-04', 2018, 2, 5, 17, 5, 5),
(3048, '2018-05-05', 2018, 2, 5, 18, 6, 6),
(3049, '2018-05-06', 2018, 2, 5, 18, 0, 7),
(3050, '2018-05-07', 2018, 2, 5, 18, 1, 8),
(3051, '2018-05-08', 2018, 2, 5, 18, 2, 9),
(3052, '2018-05-09', 2018, 2, 5, 18, 3, 10),
(3053, '2018-05-10', 2018, 2, 5, 18, 4, 11),
(3054, '2018-05-11', 2018, 2, 5, 18, 5, 12),
(3055, '2018-05-12', 2018, 2, 5, 19, 6, 13),
(3056, '2018-05-13', 2018, 2, 5, 19, 0, 14),
(3057, '2018-05-14', 2018, 2, 5, 19, 1, 15),
(3058, '2018-05-15', 2018, 2, 5, 19, 2, 16),
(3059, '2018-05-16', 2018, 2, 5, 19, 3, 17),
(3060, '2018-05-17', 2018, 2, 5, 19, 4, 18),
(3061, '2018-05-18', 2018, 2, 5, 19, 5, 19),
(3062, '2018-05-19', 2018, 2, 5, 20, 6, 20),
(3063, '2018-05-20', 2018, 2, 5, 20, 0, 21),
(3064, '2018-05-21', 2018, 2, 5, 20, 1, 22),
(3065, '2018-05-22', 2018, 2, 5, 20, 2, 23),
(3066, '2018-05-23', 2018, 2, 5, 20, 3, 24),
(3067, '2018-05-24', 2018, 2, 5, 20, 4, 25),
(3068, '2018-05-25', 2018, 2, 5, 20, 5, 26),
(3069, '2018-05-26', 2018, 2, 5, 21, 6, 27),
(3070, '2018-05-27', 2018, 2, 5, 21, 0, 28),
(3071, '2018-05-28', 2018, 2, 5, 21, 1, 29),
(3072, '2018-05-29', 2018, 2, 5, 21, 2, 30),
(3073, '2018-05-30', 2018, 2, 5, 21, 3, 31),
(3074, '2018-05-31', 2018, 2, 6, 21, 4, 1),
(3075, '2018-06-01', 2018, 2, 6, 21, 5, 2),
(3076, '2018-06-02', 2018, 2, 6, 22, 6, 3),
(3077, '2018-06-03', 2018, 2, 6, 22, 0, 4),
(3078, '2018-06-04', 2018, 2, 6, 22, 1, 5),
(3079, '2018-06-05', 2018, 2, 6, 22, 2, 6),
(3080, '2018-06-06', 2018, 2, 6, 22, 3, 7),
(3081, '2018-06-07', 2018, 2, 6, 22, 4, 8),
(3082, '2018-06-08', 2018, 2, 6, 22, 5, 9),
(3083, '2018-06-09', 2018, 2, 6, 23, 6, 10),
(3084, '2018-06-10', 2018, 2, 6, 23, 0, 11),
(3085, '2018-06-11', 2018, 2, 6, 23, 1, 12),
(3086, '2018-06-12', 2018, 2, 6, 23, 2, 13),
(3087, '2018-06-13', 2018, 2, 6, 23, 3, 14),
(3088, '2018-06-14', 2018, 2, 6, 23, 4, 15),
(3089, '2018-06-15', 2018, 2, 6, 23, 5, 16),
(3090, '2018-06-16', 2018, 2, 6, 24, 6, 17),
(3091, '2018-06-17', 2018, 2, 6, 24, 0, 18),
(3092, '2018-06-18', 2018, 2, 6, 24, 1, 19),
(3093, '2018-06-19', 2018, 2, 6, 24, 2, 20),
(3094, '2018-06-20', 2018, 2, 6, 24, 3, 21),
(3095, '2018-06-21', 2018, 2, 6, 24, 4, 22),
(3096, '2018-06-22', 2018, 2, 6, 24, 5, 23),
(3097, '2018-06-23', 2018, 2, 6, 25, 6, 24),
(3098, '2018-06-24', 2018, 2, 6, 25, 0, 25),
(3099, '2018-06-25', 2018, 2, 6, 25, 1, 26),
(3100, '2018-06-26', 2018, 2, 6, 25, 2, 27),
(3101, '2018-06-27', 2018, 2, 6, 25, 3, 28),
(3102, '2018-06-28', 2018, 2, 6, 25, 4, 29),
(3103, '2018-06-29', 2018, 2, 6, 25, 5, 30),
(3104, '2018-06-30', 2018, 3, 7, 26, 6, 1),
(3105, '2018-07-01', 2018, 3, 7, 26, 0, 2),
(3106, '2018-07-02', 2018, 3, 7, 26, 1, 3),
(3107, '2018-07-03', 2018, 3, 7, 26, 2, 4),
(3108, '2018-07-04', 2018, 3, 7, 26, 3, 5),
(3109, '2018-07-05', 2018, 3, 7, 26, 4, 6),
(3110, '2018-07-06', 2018, 3, 7, 26, 5, 7),
(3111, '2018-07-07', 2018, 3, 7, 27, 6, 8),
(3112, '2018-07-08', 2018, 3, 7, 27, 0, 9),
(3113, '2018-07-09', 2018, 3, 7, 27, 1, 10),
(3114, '2018-07-10', 2018, 3, 7, 27, 2, 11),
(3115, '2018-07-11', 2018, 3, 7, 27, 3, 12),
(3116, '2018-07-12', 2018, 3, 7, 27, 4, 13),
(3117, '2018-07-13', 2018, 3, 7, 27, 5, 14),
(3118, '2018-07-14', 2018, 3, 7, 28, 6, 15),
(3119, '2018-07-15', 2018, 3, 7, 28, 0, 16),
(3120, '2018-07-16', 2018, 3, 7, 28, 1, 17),
(3121, '2018-07-17', 2018, 3, 7, 28, 2, 18),
(3122, '2018-07-18', 2018, 3, 7, 28, 3, 19),
(3123, '2018-07-19', 2018, 3, 7, 28, 4, 20),
(3124, '2018-07-20', 2018, 3, 7, 28, 5, 21),
(3125, '2018-07-21', 2018, 3, 7, 29, 6, 22),
(3126, '2018-07-22', 2018, 3, 7, 29, 0, 23),
(3127, '2018-07-23', 2018, 3, 7, 29, 1, 24),
(3128, '2018-07-24', 2018, 3, 7, 29, 2, 25),
(3129, '2018-07-25', 2018, 3, 7, 29, 3, 26),
(3130, '2018-07-26', 2018, 3, 7, 29, 4, 27),
(3131, '2018-07-27', 2018, 3, 7, 29, 5, 28),
(3132, '2018-07-28', 2018, 3, 7, 30, 6, 29),
(3133, '2018-07-29', 2018, 3, 7, 30, 0, 30),
(3134, '2018-07-30', 2018, 3, 7, 30, 1, 31),
(3135, '2018-07-31', 2018, 3, 8, 30, 2, 1),
(3136, '2018-08-01', 2018, 3, 8, 30, 3, 2),
(3137, '2018-08-02', 2018, 3, 8, 30, 4, 3),
(3138, '2018-08-03', 2018, 3, 8, 30, 5, 4),
(3139, '2018-08-04', 2018, 3, 8, 31, 6, 5),
(3140, '2018-08-05', 2018, 3, 8, 31, 0, 6),
(3141, '2018-08-06', 2018, 3, 8, 31, 1, 7),
(3142, '2018-08-07', 2018, 3, 8, 31, 2, 8),
(3143, '2018-08-08', 2018, 3, 8, 31, 3, 9),
(3144, '2018-08-09', 2018, 3, 8, 31, 4, 10),
(3145, '2018-08-10', 2018, 3, 8, 31, 5, 11),
(3146, '2018-08-11', 2018, 3, 8, 32, 6, 12),
(3147, '2018-08-12', 2018, 3, 8, 32, 0, 13),
(3148, '2018-08-13', 2018, 3, 8, 32, 1, 14),
(3149, '2018-08-14', 2018, 3, 8, 32, 2, 15),
(3150, '2018-08-15', 2018, 3, 8, 32, 3, 16),
(3151, '2018-08-16', 2018, 3, 8, 32, 4, 17),
(3152, '2018-08-17', 2018, 3, 8, 32, 5, 18),
(3153, '2018-08-18', 2018, 3, 8, 33, 6, 19),
(3154, '2018-08-19', 2018, 3, 8, 33, 0, 20),
(3155, '2018-08-20', 2018, 3, 8, 33, 1, 21),
(3156, '2018-08-21', 2018, 3, 8, 33, 2, 22),
(3157, '2018-08-22', 2018, 3, 8, 33, 3, 23),
(3158, '2018-08-23', 2018, 3, 8, 33, 4, 24),
(3159, '2018-08-24', 2018, 3, 8, 33, 5, 25),
(3160, '2018-08-25', 2018, 3, 8, 34, 6, 26),
(3161, '2018-08-26', 2018, 3, 8, 34, 0, 27),
(3162, '2018-08-27', 2018, 3, 8, 34, 1, 28),
(3163, '2018-08-28', 2018, 3, 8, 34, 2, 29),
(3164, '2018-08-29', 2018, 3, 8, 34, 3, 30),
(3165, '2018-08-30', 2018, 3, 8, 34, 4, 31),
(3166, '2018-08-31', 2018, 3, 9, 34, 5, 1),
(3167, '2018-09-01', 2018, 3, 9, 35, 6, 2),
(3168, '2018-09-02', 2018, 3, 9, 35, 0, 3),
(3169, '2018-09-03', 2018, 3, 9, 35, 1, 4),
(3170, '2018-09-04', 2018, 3, 9, 35, 2, 5),
(3171, '2018-09-05', 2018, 3, 9, 35, 3, 6),
(3172, '2018-09-06', 2018, 3, 9, 35, 4, 7),
(3173, '2018-09-07', 2018, 3, 9, 35, 5, 8),
(3174, '2018-09-08', 2018, 3, 9, 36, 6, 9),
(3175, '2018-09-09', 2018, 3, 9, 36, 0, 10),
(3176, '2018-09-10', 2018, 3, 9, 36, 1, 11),
(3177, '2018-09-11', 2018, 3, 9, 36, 2, 12),
(3178, '2018-09-12', 2018, 3, 9, 36, 3, 13),
(3179, '2018-09-13', 2018, 3, 9, 36, 4, 14),
(3180, '2018-09-14', 2018, 3, 9, 36, 5, 15),
(3181, '2018-09-15', 2018, 3, 9, 37, 6, 16),
(3182, '2018-09-16', 2018, 3, 9, 37, 0, 17),
(3183, '2018-09-17', 2018, 3, 9, 37, 1, 18),
(3184, '2018-09-18', 2018, 3, 9, 37, 2, 19),
(3185, '2018-09-19', 2018, 3, 9, 37, 3, 20),
(3186, '2018-09-20', 2018, 3, 9, 37, 4, 21),
(3187, '2018-09-21', 2018, 3, 9, 37, 5, 22),
(3188, '2018-09-22', 2018, 3, 9, 38, 6, 23),
(3189, '2018-09-23', 2018, 3, 9, 38, 0, 24),
(3190, '2018-09-24', 2018, 3, 9, 38, 1, 25),
(3191, '2018-09-25', 2018, 3, 9, 38, 2, 26),
(3192, '2018-09-26', 2018, 3, 9, 38, 3, 27),
(3193, '2018-09-27', 2018, 3, 9, 38, 4, 28),
(3194, '2018-09-28', 2018, 3, 9, 38, 5, 29),
(3195, '2018-09-29', 2018, 3, 9, 39, 6, 30),
(3196, '2018-09-30', 2018, 4, 10, 39, 0, 1),
(3197, '2018-10-01', 2018, 4, 10, 39, 1, 2),
(3198, '2018-10-02', 2018, 4, 10, 39, 2, 3),
(3199, '2018-10-03', 2018, 4, 10, 39, 3, 4),
(3200, '2018-10-04', 2018, 4, 10, 39, 4, 5),
(3201, '2018-10-05', 2018, 4, 10, 39, 5, 6),
(3202, '2018-10-06', 2018, 4, 10, 40, 6, 7),
(3203, '2018-10-07', 2018, 4, 10, 40, 0, 8),
(3204, '2018-10-08', 2018, 4, 10, 40, 1, 9),
(3205, '2018-10-09', 2018, 4, 10, 40, 2, 10),
(3206, '2018-10-10', 2018, 4, 10, 40, 3, 11),
(3207, '2018-10-11', 2018, 4, 10, 40, 4, 12),
(3208, '2018-10-12', 2018, 4, 10, 40, 5, 13),
(3209, '2018-10-13', 2018, 4, 10, 41, 6, 14),
(3210, '2018-10-14', 2018, 4, 10, 41, 0, 15),
(3211, '2018-10-15', 2018, 4, 10, 41, 1, 16),
(3212, '2018-10-16', 2018, 4, 10, 41, 2, 17),
(3213, '2018-10-17', 2018, 4, 10, 41, 3, 18),
(3214, '2018-10-18', 2018, 4, 10, 41, 4, 19),
(3215, '2018-10-19', 2018, 4, 10, 41, 5, 20),
(3216, '2018-10-20', 2018, 4, 10, 42, 6, 21),
(3217, '2018-10-21', 2018, 4, 10, 42, 0, 22),
(3218, '2018-10-22', 2018, 4, 10, 42, 1, 23),
(3219, '2018-10-23', 2018, 4, 10, 42, 2, 24),
(3220, '2018-10-24', 2018, 4, 10, 42, 3, 25),
(3221, '2018-10-25', 2018, 4, 10, 42, 4, 26),
(3222, '2018-10-26', 2018, 4, 10, 42, 5, 27),
(3223, '2018-10-27', 2018, 4, 10, 43, 6, 28),
(3224, '2018-10-28', 2018, 4, 10, 43, 0, 29),
(3225, '2018-10-29', 2018, 4, 10, 43, 1, 30),
(3226, '2018-10-30', 2018, 4, 10, 43, 2, 31),
(3227, '2018-10-31', 2018, 4, 11, 43, 3, 1),
(3228, '2018-11-01', 2018, 4, 11, 43, 4, 2),
(3229, '2018-11-02', 2018, 4, 11, 43, 5, 3),
(3230, '2018-11-03', 2018, 4, 11, 44, 6, 4),
(3231, '2018-11-04', 2018, 4, 11, 44, 0, 5),
(3232, '2018-11-05', 2018, 4, 11, 44, 1, 6),
(3233, '2018-11-06', 2018, 4, 11, 44, 2, 7),
(3234, '2018-11-07', 2018, 4, 11, 44, 3, 8),
(3235, '2018-11-08', 2018, 4, 11, 44, 4, 9),
(3236, '2018-11-09', 2018, 4, 11, 44, 5, 10),
(3237, '2018-11-10', 2018, 4, 11, 45, 6, 11),
(3238, '2018-11-11', 2018, 4, 11, 45, 0, 12),
(3239, '2018-11-12', 2018, 4, 11, 45, 1, 13),
(3240, '2018-11-13', 2018, 4, 11, 45, 2, 14),
(3241, '2018-11-14', 2018, 4, 11, 45, 3, 15),
(3242, '2018-11-15', 2018, 4, 11, 45, 4, 16),
(3243, '2018-11-16', 2018, 4, 11, 45, 5, 17),
(3244, '2018-11-17', 2018, 4, 11, 46, 6, 18),
(3245, '2018-11-18', 2018, 4, 11, 46, 0, 19),
(3246, '2018-11-19', 2018, 4, 11, 46, 1, 20),
(3247, '2018-11-20', 2018, 4, 11, 46, 2, 21),
(3248, '2018-11-21', 2018, 4, 11, 46, 3, 22),
(3249, '2018-11-22', 2018, 4, 11, 46, 4, 23),
(3250, '2018-11-23', 2018, 4, 11, 46, 5, 24),
(3251, '2018-11-24', 2018, 4, 11, 47, 6, 25),
(3252, '2018-11-25', 2018, 4, 11, 47, 0, 26),
(3253, '2018-11-26', 2018, 4, 11, 47, 1, 27),
(3254, '2018-11-27', 2018, 4, 11, 47, 2, 28),
(3255, '2018-11-28', 2018, 4, 11, 47, 3, 29),
(3256, '2018-11-29', 2018, 4, 11, 47, 4, 30),
(3257, '2018-11-30', 2018, 4, 12, 47, 5, 1),
(3258, '2018-12-01', 2018, 4, 12, 48, 6, 2),
(3259, '2018-12-02', 2018, 4, 12, 48, 0, 3),
(3260, '2018-12-03', 2018, 4, 12, 48, 1, 4),
(3261, '2018-12-04', 2018, 4, 12, 48, 2, 5),
(3262, '2018-12-05', 2018, 4, 12, 48, 3, 6),
(3263, '2018-12-06', 2018, 4, 12, 48, 4, 7),
(3264, '2018-12-07', 2018, 4, 12, 48, 5, 8),
(3265, '2018-12-08', 2018, 4, 12, 49, 6, 9),
(3266, '2018-12-09', 2018, 4, 12, 49, 0, 10),
(3267, '2018-12-10', 2018, 4, 12, 49, 1, 11),
(3268, '2018-12-11', 2018, 4, 12, 49, 2, 12),
(3269, '2018-12-12', 2018, 4, 12, 49, 3, 13),
(3270, '2018-12-13', 2018, 4, 12, 49, 4, 14),
(3271, '2018-12-14', 2018, 4, 12, 49, 5, 15),
(3272, '2018-12-15', 2018, 4, 12, 50, 6, 16),
(3273, '2018-12-16', 2018, 4, 12, 50, 0, 17),
(3274, '2018-12-17', 2018, 4, 12, 50, 1, 18),
(3275, '2018-12-18', 2018, 4, 12, 50, 2, 19),
(3276, '2018-12-19', 2018, 4, 12, 50, 3, 20),
(3277, '2018-12-20', 2018, 4, 12, 50, 4, 21),
(3278, '2018-12-21', 2018, 4, 12, 50, 5, 22),
(3279, '2018-12-22', 2018, 4, 12, 51, 6, 23),
(3280, '2018-12-23', 2018, 4, 12, 51, 0, 24),
(3281, '2018-12-24', 2018, 4, 12, 51, 1, 25),
(3282, '2018-12-25', 2018, 4, 12, 51, 2, 26),
(3283, '2018-12-26', 2018, 4, 12, 51, 3, 27),
(3284, '2018-12-27', 2018, 4, 12, 51, 4, 28),
(3285, '2018-12-28', 2018, 4, 12, 51, 5, 29),
(3286, '2018-12-29', 2018, 4, 12, 52, 6, 30),
(3287, '2018-12-30', 2018, 4, 12, 52, 0, 31),
(3288, '2018-12-31', 2019, 1, 1, 0, 1, 1),
(3289, '2019-01-01', 2019, 1, 1, 0, 2, 2),
(3290, '2019-01-02', 2019, 1, 1, 0, 3, 3),
(3291, '2019-01-03', 2019, 1, 1, 0, 4, 4),
(3292, '2019-01-04', 2019, 1, 1, 0, 5, 5),
(3293, '2019-01-05', 2019, 1, 1, 1, 6, 6),
(3294, '2019-01-06', 2019, 1, 1, 1, 0, 7),
(3295, '2019-01-07', 2019, 1, 1, 1, 1, 8),
(3296, '2019-01-08', 2019, 1, 1, 1, 2, 9),
(3297, '2019-01-09', 2019, 1, 1, 1, 3, 10),
(3298, '2019-01-10', 2019, 1, 1, 1, 4, 11),
(3299, '2019-01-11', 2019, 1, 1, 1, 5, 12),
(3300, '2019-01-12', 2019, 1, 1, 2, 6, 13),
(3301, '2019-01-13', 2019, 1, 1, 2, 0, 14),
(3302, '2019-01-14', 2019, 1, 1, 2, 1, 15),
(3303, '2019-01-15', 2019, 1, 1, 2, 2, 16),
(3304, '2019-01-16', 2019, 1, 1, 2, 3, 17),
(3305, '2019-01-17', 2019, 1, 1, 2, 4, 18),
(3306, '2019-01-18', 2019, 1, 1, 2, 5, 19),
(3307, '2019-01-19', 2019, 1, 1, 3, 6, 20),
(3308, '2019-01-20', 2019, 1, 1, 3, 0, 21),
(3309, '2019-01-21', 2019, 1, 1, 3, 1, 22),
(3310, '2019-01-22', 2019, 1, 1, 3, 2, 23),
(3311, '2019-01-23', 2019, 1, 1, 3, 3, 24),
(3312, '2019-01-24', 2019, 1, 1, 3, 4, 25),
(3313, '2019-01-25', 2019, 1, 1, 3, 5, 26),
(3314, '2019-01-26', 2019, 1, 1, 4, 6, 27),
(3315, '2019-01-27', 2019, 1, 1, 4, 0, 28),
(3316, '2019-01-28', 2019, 1, 1, 4, 1, 29),
(3317, '2019-01-29', 2019, 1, 1, 4, 2, 30),
(3318, '2019-01-30', 2019, 1, 1, 4, 3, 31),
(3319, '2019-01-31', 2019, 1, 2, 4, 4, 1),
(3320, '2019-02-01', 2019, 1, 2, 4, 5, 2),
(3321, '2019-02-02', 2019, 1, 2, 5, 6, 3),
(3322, '2019-02-03', 2019, 1, 2, 5, 0, 4),
(3323, '2019-02-04', 2019, 1, 2, 5, 1, 5),
(3324, '2019-02-05', 2019, 1, 2, 5, 2, 6),
(3325, '2019-02-06', 2019, 1, 2, 5, 3, 7),
(3326, '2019-02-07', 2019, 1, 2, 5, 4, 8),
(3327, '2019-02-08', 2019, 1, 2, 5, 5, 9),
(3328, '2019-02-09', 2019, 1, 2, 6, 6, 10),
(3329, '2019-02-10', 2019, 1, 2, 6, 0, 11),
(3330, '2019-02-11', 2019, 1, 2, 6, 1, 12),
(3331, '2019-02-12', 2019, 1, 2, 6, 2, 13),
(3332, '2019-02-13', 2019, 1, 2, 6, 3, 14),
(3333, '2019-02-14', 2019, 1, 2, 6, 4, 15),
(3334, '2019-02-15', 2019, 1, 2, 6, 5, 16),
(3335, '2019-02-16', 2019, 1, 2, 7, 6, 17),
(3336, '2019-02-17', 2019, 1, 2, 7, 0, 18),
(3337, '2019-02-18', 2019, 1, 2, 7, 1, 19),
(3338, '2019-02-19', 2019, 1, 2, 7, 2, 20),
(3339, '2019-02-20', 2019, 1, 2, 7, 3, 21),
(3340, '2019-02-21', 2019, 1, 2, 7, 4, 22),
(3341, '2019-02-22', 2019, 1, 2, 7, 5, 23),
(3342, '2019-02-23', 2019, 1, 2, 8, 6, 24),
(3343, '2019-02-24', 2019, 1, 2, 8, 0, 25),
(3344, '2019-02-25', 2019, 1, 2, 8, 1, 26),
(3345, '2019-02-26', 2019, 1, 2, 8, 2, 27),
(3346, '2019-02-27', 2019, 1, 2, 8, 3, 28),
(3347, '2019-02-28', 2019, 1, 3, 8, 4, 1),
(3348, '2019-03-01', 2019, 1, 3, 8, 5, 2),
(3349, '2019-03-02', 2019, 1, 3, 9, 6, 3),
(3350, '2019-03-03', 2019, 1, 3, 9, 0, 4),
(3351, '2019-03-04', 2019, 1, 3, 9, 1, 5),
(3352, '2019-03-05', 2019, 1, 3, 9, 2, 6),
(3353, '2019-03-06', 2019, 1, 3, 9, 3, 7),
(3354, '2019-03-07', 2019, 1, 3, 9, 4, 8),
(3355, '2019-03-08', 2019, 1, 3, 9, 5, 9),
(3356, '2019-03-09', 2019, 1, 3, 10, 6, 10),
(3357, '2019-03-10', 2019, 1, 3, 10, 0, 11),
(3358, '2019-03-11', 2019, 1, 3, 10, 1, 12),
(3359, '2019-03-12', 2019, 1, 3, 10, 2, 13),
(3360, '2019-03-13', 2019, 1, 3, 10, 3, 14),
(3361, '2019-03-14', 2019, 1, 3, 10, 4, 15),
(3362, '2019-03-15', 2019, 1, 3, 10, 5, 16),
(3363, '2019-03-16', 2019, 1, 3, 11, 6, 17),
(3364, '2019-03-17', 2019, 1, 3, 11, 0, 18),
(3365, '2019-03-18', 2019, 1, 3, 11, 1, 19),
(3366, '2019-03-19', 2019, 1, 3, 11, 2, 20),
(3367, '2019-03-20', 2019, 1, 3, 11, 3, 21),
(3368, '2019-03-21', 2019, 1, 3, 11, 4, 22),
(3369, '2019-03-22', 2019, 1, 3, 11, 5, 23),
(3370, '2019-03-23', 2019, 1, 3, 12, 6, 24),
(3371, '2019-03-24', 2019, 1, 3, 12, 0, 25),
(3372, '2019-03-25', 2019, 1, 3, 12, 1, 26),
(3373, '2019-03-26', 2019, 1, 3, 12, 2, 27),
(3374, '2019-03-27', 2019, 1, 3, 12, 3, 28),
(3375, '2019-03-28', 2019, 1, 3, 12, 4, 29),
(3376, '2019-03-29', 2019, 1, 3, 12, 5, 30),
(3377, '2019-03-30', 2019, 1, 3, 13, 6, 31),
(3378, '2019-03-31', 2019, 2, 4, 13, 0, 1),
(3379, '2019-04-01', 2019, 2, 4, 13, 1, 2),
(3380, '2019-04-02', 2019, 2, 4, 13, 2, 3),
(3381, '2019-04-03', 2019, 2, 4, 13, 3, 4),
(3382, '2019-04-04', 2019, 2, 4, 13, 4, 5),
(3383, '2019-04-05', 2019, 2, 4, 13, 5, 6),
(3384, '2019-04-06', 2019, 2, 4, 14, 6, 7),
(3385, '2019-04-07', 2019, 2, 4, 14, 0, 8),
(3386, '2019-04-08', 2019, 2, 4, 14, 1, 9),
(3387, '2019-04-09', 2019, 2, 4, 14, 2, 10),
(3388, '2019-04-10', 2019, 2, 4, 14, 3, 11),
(3389, '2019-04-11', 2019, 2, 4, 14, 4, 12),
(3390, '2019-04-12', 2019, 2, 4, 14, 5, 13),
(3391, '2019-04-13', 2019, 2, 4, 15, 6, 14),
(3392, '2019-04-14', 2019, 2, 4, 15, 0, 15),
(3393, '2019-04-15', 2019, 2, 4, 15, 1, 16),
(3394, '2019-04-16', 2019, 2, 4, 15, 2, 17),
(3395, '2019-04-17', 2019, 2, 4, 15, 3, 18),
(3396, '2019-04-18', 2019, 2, 4, 15, 4, 19),
(3397, '2019-04-19', 2019, 2, 4, 15, 5, 20),
(3398, '2019-04-20', 2019, 2, 4, 16, 6, 21),
(3399, '2019-04-21', 2019, 2, 4, 16, 0, 22),
(3400, '2019-04-22', 2019, 2, 4, 16, 1, 23),
(3401, '2019-04-23', 2019, 2, 4, 16, 2, 24),
(3402, '2019-04-24', 2019, 2, 4, 16, 3, 25),
(3403, '2019-04-25', 2019, 2, 4, 16, 4, 26),
(3404, '2019-04-26', 2019, 2, 4, 16, 5, 27),
(3405, '2019-04-27', 2019, 2, 4, 17, 6, 28),
(3406, '2019-04-28', 2019, 2, 4, 17, 0, 29),
(3407, '2019-04-29', 2019, 2, 4, 17, 1, 30),
(3408, '2019-04-30', 2019, 2, 5, 17, 2, 1),
(3409, '2019-05-01', 2019, 2, 5, 17, 3, 2),
(3410, '2019-05-02', 2019, 2, 5, 17, 4, 3),
(3411, '2019-05-03', 2019, 2, 5, 17, 5, 4),
(3412, '2019-05-04', 2019, 2, 5, 18, 6, 5),
(3413, '2019-05-05', 2019, 2, 5, 18, 0, 6),
(3414, '2019-05-06', 2019, 2, 5, 18, 1, 7),
(3415, '2019-05-07', 2019, 2, 5, 18, 2, 8),
(3416, '2019-05-08', 2019, 2, 5, 18, 3, 9),
(3417, '2019-05-09', 2019, 2, 5, 18, 4, 10),
(3418, '2019-05-10', 2019, 2, 5, 18, 5, 11),
(3419, '2019-05-11', 2019, 2, 5, 19, 6, 12),
(3420, '2019-05-12', 2019, 2, 5, 19, 0, 13),
(3421, '2019-05-13', 2019, 2, 5, 19, 1, 14),
(3422, '2019-05-14', 2019, 2, 5, 19, 2, 15),
(3423, '2019-05-15', 2019, 2, 5, 19, 3, 16),
(3424, '2019-05-16', 2019, 2, 5, 19, 4, 17),
(3425, '2019-05-17', 2019, 2, 5, 19, 5, 18),
(3426, '2019-05-18', 2019, 2, 5, 20, 6, 19),
(3427, '2019-05-19', 2019, 2, 5, 20, 0, 20),
(3428, '2019-05-20', 2019, 2, 5, 20, 1, 21),
(3429, '2019-05-21', 2019, 2, 5, 20, 2, 22),
(3430, '2019-05-22', 2019, 2, 5, 20, 3, 23),
(3431, '2019-05-23', 2019, 2, 5, 20, 4, 24),
(3432, '2019-05-24', 2019, 2, 5, 20, 5, 25),
(3433, '2019-05-25', 2019, 2, 5, 21, 6, 26),
(3434, '2019-05-26', 2019, 2, 5, 21, 0, 27),
(3435, '2019-05-27', 2019, 2, 5, 21, 1, 28),
(3436, '2019-05-28', 2019, 2, 5, 21, 2, 29),
(3437, '2019-05-29', 2019, 2, 5, 21, 3, 30),
(3438, '2019-05-30', 2019, 2, 5, 21, 4, 31),
(3439, '2019-05-31', 2019, 2, 6, 21, 5, 1),
(3440, '2019-06-01', 2019, 2, 6, 22, 6, 2),
(3441, '2019-06-02', 2019, 2, 6, 22, 0, 3),
(3442, '2019-06-03', 2019, 2, 6, 22, 1, 4),
(3443, '2019-06-04', 2019, 2, 6, 22, 2, 5),
(3444, '2019-06-05', 2019, 2, 6, 22, 3, 6),
(3445, '2019-06-06', 2019, 2, 6, 22, 4, 7),
(3446, '2019-06-07', 2019, 2, 6, 22, 5, 8),
(3447, '2019-06-08', 2019, 2, 6, 23, 6, 9),
(3448, '2019-06-09', 2019, 2, 6, 23, 0, 10),
(3449, '2019-06-10', 2019, 2, 6, 23, 1, 11),
(3450, '2019-06-11', 2019, 2, 6, 23, 2, 12),
(3451, '2019-06-12', 2019, 2, 6, 23, 3, 13),
(3452, '2019-06-13', 2019, 2, 6, 23, 4, 14),
(3453, '2019-06-14', 2019, 2, 6, 23, 5, 15),
(3454, '2019-06-15', 2019, 2, 6, 24, 6, 16),
(3455, '2019-06-16', 2019, 2, 6, 24, 0, 17),
(3456, '2019-06-17', 2019, 2, 6, 24, 1, 18),
(3457, '2019-06-18', 2019, 2, 6, 24, 2, 19),
(3458, '2019-06-19', 2019, 2, 6, 24, 3, 20),
(3459, '2019-06-20', 2019, 2, 6, 24, 4, 21),
(3460, '2019-06-21', 2019, 2, 6, 24, 5, 22),
(3461, '2019-06-22', 2019, 2, 6, 25, 6, 23),
(3462, '2019-06-23', 2019, 2, 6, 25, 0, 24),
(3463, '2019-06-24', 2019, 2, 6, 25, 1, 25),
(3464, '2019-06-25', 2019, 2, 6, 25, 2, 26),
(3465, '2019-06-26', 2019, 2, 6, 25, 3, 27),
(3466, '2019-06-27', 2019, 2, 6, 25, 4, 28),
(3467, '2019-06-28', 2019, 2, 6, 25, 5, 29),
(3468, '2019-06-29', 2019, 2, 6, 26, 6, 30),
(3469, '2019-06-30', 2019, 3, 7, 26, 0, 1),
(3470, '2019-07-01', 2019, 3, 7, 26, 1, 2),
(3471, '2019-07-02', 2019, 3, 7, 26, 2, 3),
(3472, '2019-07-03', 2019, 3, 7, 26, 3, 4),
(3473, '2019-07-04', 2019, 3, 7, 26, 4, 5),
(3474, '2019-07-05', 2019, 3, 7, 26, 5, 6),
(3475, '2019-07-06', 2019, 3, 7, 27, 6, 7),
(3476, '2019-07-07', 2019, 3, 7, 27, 0, 8),
(3477, '2019-07-08', 2019, 3, 7, 27, 1, 9),
(3478, '2019-07-09', 2019, 3, 7, 27, 2, 10),
(3479, '2019-07-10', 2019, 3, 7, 27, 3, 11),
(3480, '2019-07-11', 2019, 3, 7, 27, 4, 12),
(3481, '2019-07-12', 2019, 3, 7, 27, 5, 13),
(3482, '2019-07-13', 2019, 3, 7, 28, 6, 14),
(3483, '2019-07-14', 2019, 3, 7, 28, 0, 15),
(3484, '2019-07-15', 2019, 3, 7, 28, 1, 16),
(3485, '2019-07-16', 2019, 3, 7, 28, 2, 17),
(3486, '2019-07-17', 2019, 3, 7, 28, 3, 18),
(3487, '2019-07-18', 2019, 3, 7, 28, 4, 19),
(3488, '2019-07-19', 2019, 3, 7, 28, 5, 20),
(3489, '2019-07-20', 2019, 3, 7, 29, 6, 21),
(3490, '2019-07-21', 2019, 3, 7, 29, 0, 22),
(3491, '2019-07-22', 2019, 3, 7, 29, 1, 23),
(3492, '2019-07-23', 2019, 3, 7, 29, 2, 24),
(3493, '2019-07-24', 2019, 3, 7, 29, 3, 25),
(3494, '2019-07-25', 2019, 3, 7, 29, 4, 26),
(3495, '2019-07-26', 2019, 3, 7, 29, 5, 27),
(3496, '2019-07-27', 2019, 3, 7, 30, 6, 28),
(3497, '2019-07-28', 2019, 3, 7, 30, 0, 29),
(3498, '2019-07-29', 2019, 3, 7, 30, 1, 30),
(3499, '2019-07-30', 2019, 3, 7, 30, 2, 31),
(3500, '2019-07-31', 2019, 3, 8, 30, 3, 1),
(3501, '2019-08-01', 2019, 3, 8, 30, 4, 2),
(3502, '2019-08-02', 2019, 3, 8, 30, 5, 3),
(3503, '2019-08-03', 2019, 3, 8, 31, 6, 4),
(3504, '2019-08-04', 2019, 3, 8, 31, 0, 5),
(3505, '2019-08-05', 2019, 3, 8, 31, 1, 6),
(3506, '2019-08-06', 2019, 3, 8, 31, 2, 7),
(3507, '2019-08-07', 2019, 3, 8, 31, 3, 8),
(3508, '2019-08-08', 2019, 3, 8, 31, 4, 9),
(3509, '2019-08-09', 2019, 3, 8, 31, 5, 10),
(3510, '2019-08-10', 2019, 3, 8, 32, 6, 11),
(3511, '2019-08-11', 2019, 3, 8, 32, 0, 12),
(3512, '2019-08-12', 2019, 3, 8, 32, 1, 13),
(3513, '2019-08-13', 2019, 3, 8, 32, 2, 14),
(3514, '2019-08-14', 2019, 3, 8, 32, 3, 15),
(3515, '2019-08-15', 2019, 3, 8, 32, 4, 16),
(3516, '2019-08-16', 2019, 3, 8, 32, 5, 17),
(3517, '2019-08-17', 2019, 3, 8, 33, 6, 18),
(3518, '2019-08-18', 2019, 3, 8, 33, 0, 19),
(3519, '2019-08-19', 2019, 3, 8, 33, 1, 20),
(3520, '2019-08-20', 2019, 3, 8, 33, 2, 21),
(3521, '2019-08-21', 2019, 3, 8, 33, 3, 22),
(3522, '2019-08-22', 2019, 3, 8, 33, 4, 23),
(3523, '2019-08-23', 2019, 3, 8, 33, 5, 24),
(3524, '2019-08-24', 2019, 3, 8, 34, 6, 25),
(3525, '2019-08-25', 2019, 3, 8, 34, 0, 26),
(3526, '2019-08-26', 2019, 3, 8, 34, 1, 27),
(3527, '2019-08-27', 2019, 3, 8, 34, 2, 28),
(3528, '2019-08-28', 2019, 3, 8, 34, 3, 29),
(3529, '2019-08-29', 2019, 3, 8, 34, 4, 30),
(3530, '2019-08-30', 2019, 3, 8, 34, 5, 31),
(3531, '2019-08-31', 2019, 3, 9, 35, 6, 1),
(3532, '2019-09-01', 2019, 3, 9, 35, 0, 2),
(3533, '2019-09-02', 2019, 3, 9, 35, 1, 3),
(3534, '2019-09-03', 2019, 3, 9, 35, 2, 4),
(3535, '2019-09-04', 2019, 3, 9, 35, 3, 5),
(3536, '2019-09-05', 2019, 3, 9, 35, 4, 6),
(3537, '2019-09-06', 2019, 3, 9, 35, 5, 7),
(3538, '2019-09-07', 2019, 3, 9, 36, 6, 8),
(3539, '2019-09-08', 2019, 3, 9, 36, 0, 9),
(3540, '2019-09-09', 2019, 3, 9, 36, 1, 10),
(3541, '2019-09-10', 2019, 3, 9, 36, 2, 11),
(3542, '2019-09-11', 2019, 3, 9, 36, 3, 12),
(3543, '2019-09-12', 2019, 3, 9, 36, 4, 13),
(3544, '2019-09-13', 2019, 3, 9, 36, 5, 14),
(3545, '2019-09-14', 2019, 3, 9, 37, 6, 15),
(3546, '2019-09-15', 2019, 3, 9, 37, 0, 16),
(3547, '2019-09-16', 2019, 3, 9, 37, 1, 17),
(3548, '2019-09-17', 2019, 3, 9, 37, 2, 18),
(3549, '2019-09-18', 2019, 3, 9, 37, 3, 19),
(3550, '2019-09-19', 2019, 3, 9, 37, 4, 20),
(3551, '2019-09-20', 2019, 3, 9, 37, 5, 21),
(3552, '2019-09-21', 2019, 3, 9, 38, 6, 22),
(3553, '2019-09-22', 2019, 3, 9, 38, 0, 23),
(3554, '2019-09-23', 2019, 3, 9, 38, 1, 24),
(3555, '2019-09-24', 2019, 3, 9, 38, 2, 25),
(3556, '2019-09-25', 2019, 3, 9, 38, 3, 26),
(3557, '2019-09-26', 2019, 3, 9, 38, 4, 27),
(3558, '2019-09-27', 2019, 3, 9, 38, 5, 28),
(3559, '2019-09-28', 2019, 3, 9, 39, 6, 29),
(3560, '2019-09-29', 2019, 3, 9, 39, 0, 30),
(3561, '2019-09-30', 2019, 4, 10, 39, 1, 1),
(3562, '2019-10-01', 2019, 4, 10, 39, 2, 2),
(3563, '2019-10-02', 2019, 4, 10, 39, 3, 3),
(3564, '2019-10-03', 2019, 4, 10, 39, 4, 4),
(3565, '2019-10-04', 2019, 4, 10, 39, 5, 5),
(3566, '2019-10-05', 2019, 4, 10, 40, 6, 6),
(3567, '2019-10-06', 2019, 4, 10, 40, 0, 7),
(3568, '2019-10-07', 2019, 4, 10, 40, 1, 8),
(3569, '2019-10-08', 2019, 4, 10, 40, 2, 9),
(3570, '2019-10-09', 2019, 4, 10, 40, 3, 10),
(3571, '2019-10-10', 2019, 4, 10, 40, 4, 11),
(3572, '2019-10-11', 2019, 4, 10, 40, 5, 12),
(3573, '2019-10-12', 2019, 4, 10, 41, 6, 13),
(3574, '2019-10-13', 2019, 4, 10, 41, 0, 14),
(3575, '2019-10-14', 2019, 4, 10, 41, 1, 15),
(3576, '2019-10-15', 2019, 4, 10, 41, 2, 16),
(3577, '2019-10-16', 2019, 4, 10, 41, 3, 17),
(3578, '2019-10-17', 2019, 4, 10, 41, 4, 18),
(3579, '2019-10-18', 2019, 4, 10, 41, 5, 19),
(3580, '2019-10-19', 2019, 4, 10, 42, 6, 20),
(3581, '2019-10-20', 2019, 4, 10, 42, 0, 21),
(3582, '2019-10-21', 2019, 4, 10, 42, 1, 22),
(3583, '2019-10-22', 2019, 4, 10, 42, 2, 23),
(3584, '2019-10-23', 2019, 4, 10, 42, 3, 24),
(3585, '2019-10-24', 2019, 4, 10, 42, 4, 25),
(3586, '2019-10-25', 2019, 4, 10, 42, 5, 26),
(3587, '2019-10-26', 2019, 4, 10, 43, 6, 27),
(3588, '2019-10-27', 2019, 4, 10, 43, 0, 28),
(3589, '2019-10-28', 2019, 4, 10, 43, 1, 29),
(3590, '2019-10-29', 2019, 4, 10, 43, 2, 30),
(3591, '2019-10-30', 2019, 4, 10, 43, 3, 31),
(3592, '2019-10-31', 2019, 4, 11, 43, 4, 1),
(3593, '2019-11-01', 2019, 4, 11, 43, 5, 2),
(3594, '2019-11-02', 2019, 4, 11, 44, 6, 3),
(3595, '2019-11-03', 2019, 4, 11, 44, 0, 4),
(3596, '2019-11-04', 2019, 4, 11, 44, 1, 5),
(3597, '2019-11-05', 2019, 4, 11, 44, 2, 6),
(3598, '2019-11-06', 2019, 4, 11, 44, 3, 7),
(3599, '2019-11-07', 2019, 4, 11, 44, 4, 8),
(3600, '2019-11-08', 2019, 4, 11, 44, 5, 9),
(3601, '2019-11-09', 2019, 4, 11, 45, 6, 10),
(3602, '2019-11-10', 2019, 4, 11, 45, 0, 11),
(3603, '2019-11-11', 2019, 4, 11, 45, 1, 12),
(3604, '2019-11-12', 2019, 4, 11, 45, 2, 13),
(3605, '2019-11-13', 2019, 4, 11, 45, 3, 14),
(3606, '2019-11-14', 2019, 4, 11, 45, 4, 15),
(3607, '2019-11-15', 2019, 4, 11, 45, 5, 16),
(3608, '2019-11-16', 2019, 4, 11, 46, 6, 17),
(3609, '2019-11-17', 2019, 4, 11, 46, 0, 18),
(3610, '2019-11-18', 2019, 4, 11, 46, 1, 19),
(3611, '2019-11-19', 2019, 4, 11, 46, 2, 20),
(3612, '2019-11-20', 2019, 4, 11, 46, 3, 21),
(3613, '2019-11-21', 2019, 4, 11, 46, 4, 22),
(3614, '2019-11-22', 2019, 4, 11, 46, 5, 23),
(3615, '2019-11-23', 2019, 4, 11, 47, 6, 24),
(3616, '2019-11-24', 2019, 4, 11, 47, 0, 25),
(3617, '2019-11-25', 2019, 4, 11, 47, 1, 26),
(3618, '2019-11-26', 2019, 4, 11, 47, 2, 27),
(3619, '2019-11-27', 2019, 4, 11, 47, 3, 28),
(3620, '2019-11-28', 2019, 4, 11, 47, 4, 29),
(3621, '2019-11-29', 2019, 4, 11, 47, 5, 30),
(3622, '2019-11-30', 2019, 4, 12, 48, 6, 1),
(3623, '2019-12-01', 2019, 4, 12, 48, 0, 2),
(3624, '2019-12-02', 2019, 4, 12, 48, 1, 3),
(3625, '2019-12-03', 2019, 4, 12, 48, 2, 4),
(3626, '2019-12-04', 2019, 4, 12, 48, 3, 5),
(3627, '2019-12-05', 2019, 4, 12, 48, 4, 6),
(3628, '2019-12-06', 2019, 4, 12, 48, 5, 7),
(3629, '2019-12-07', 2019, 4, 12, 49, 6, 8),
(3630, '2019-12-08', 2019, 4, 12, 49, 0, 9),
(3631, '2019-12-09', 2019, 4, 12, 49, 1, 10),
(3632, '2019-12-10', 2019, 4, 12, 49, 2, 11),
(3633, '2019-12-11', 2019, 4, 12, 49, 3, 12),
(3634, '2019-12-12', 2019, 4, 12, 49, 4, 13),
(3635, '2019-12-13', 2019, 4, 12, 49, 5, 14),
(3636, '2019-12-14', 2019, 4, 12, 50, 6, 15),
(3637, '2019-12-15', 2019, 4, 12, 50, 0, 16),
(3638, '2019-12-16', 2019, 4, 12, 50, 1, 17),
(3639, '2019-12-17', 2019, 4, 12, 50, 2, 18),
(3640, '2019-12-18', 2019, 4, 12, 50, 3, 19),
(3641, '2019-12-19', 2019, 4, 12, 50, 4, 20),
(3642, '2019-12-20', 2019, 4, 12, 50, 5, 21),
(3643, '2019-12-21', 2019, 4, 12, 51, 6, 22),
(3644, '2019-12-22', 2019, 4, 12, 51, 0, 23),
(3645, '2019-12-23', 2019, 4, 12, 51, 1, 24),
(3646, '2019-12-24', 2019, 4, 12, 51, 2, 25),
(3647, '2019-12-25', 2019, 4, 12, 51, 3, 26),
(3648, '2019-12-26', 2019, 4, 12, 51, 4, 27),
(3649, '2019-12-27', 2019, 4, 12, 51, 5, 28),
(3650, '2019-12-28', 2019, 4, 12, 52, 6, 29),
(3651, '2019-12-29', 2019, 4, 12, 52, 0, 30),
(3652, '2019-12-30', 2019, 4, 12, 52, 1, 31),
(3653, '2019-12-31', 2020, 1, 1, 0, 2, 1),
(3654, '2020-01-01', 2020, 1, 1, 0, 3, 2),
(3655, '2020-01-02', 2020, 1, 1, 0, 4, 3),
(3656, '2020-01-03', 2020, 1, 1, 0, 5, 4),
(3657, '2020-01-04', 2020, 1, 1, 1, 6, 5),
(3658, '2020-01-05', 2020, 1, 1, 1, 0, 6),
(3659, '2020-01-06', 2020, 1, 1, 1, 1, 7),
(3660, '2020-01-07', 2020, 1, 1, 1, 2, 8),
(3661, '2020-01-08', 2020, 1, 1, 1, 3, 9),
(3662, '2020-01-09', 2020, 1, 1, 1, 4, 10),
(3663, '2020-01-10', 2020, 1, 1, 1, 5, 11),
(3664, '2020-01-11', 2020, 1, 1, 2, 6, 12),
(3665, '2020-01-12', 2020, 1, 1, 2, 0, 13),
(3666, '2020-01-13', 2020, 1, 1, 2, 1, 14),
(3667, '2020-01-14', 2020, 1, 1, 2, 2, 15),
(3668, '2020-01-15', 2020, 1, 1, 2, 3, 16),
(3669, '2020-01-16', 2020, 1, 1, 2, 4, 17),
(3670, '2020-01-17', 2020, 1, 1, 2, 5, 18),
(3671, '2020-01-18', 2020, 1, 1, 3, 6, 19),
(3672, '2020-01-19', 2020, 1, 1, 3, 0, 20),
(3673, '2020-01-20', 2020, 1, 1, 3, 1, 21),
(3674, '2020-01-21', 2020, 1, 1, 3, 2, 22),
(3675, '2020-01-22', 2020, 1, 1, 3, 3, 23),
(3676, '2020-01-23', 2020, 1, 1, 3, 4, 24),
(3677, '2020-01-24', 2020, 1, 1, 3, 5, 25),
(3678, '2020-01-25', 2020, 1, 1, 4, 6, 26),
(3679, '2020-01-26', 2020, 1, 1, 4, 0, 27),
(3680, '2020-01-27', 2020, 1, 1, 4, 1, 28),
(3681, '2020-01-28', 2020, 1, 1, 4, 2, 29),
(3682, '2020-01-29', 2020, 1, 1, 4, 3, 30),
(3683, '2020-01-30', 2020, 1, 1, 4, 4, 31),
(3684, '2020-01-31', 2020, 1, 2, 4, 5, 1),
(3685, '2020-02-01', 2020, 1, 2, 5, 6, 2),
(3686, '2020-02-02', 2020, 1, 2, 5, 0, 3),
(3687, '2020-02-03', 2020, 1, 2, 5, 1, 4),
(3688, '2020-02-04', 2020, 1, 2, 5, 2, 5),
(3689, '2020-02-05', 2020, 1, 2, 5, 3, 6),
(3690, '2020-02-06', 2020, 1, 2, 5, 4, 7),
(3691, '2020-02-07', 2020, 1, 2, 5, 5, 8),
(3692, '2020-02-08', 2020, 1, 2, 6, 6, 9),
(3693, '2020-02-09', 2020, 1, 2, 6, 0, 10),
(3694, '2020-02-10', 2020, 1, 2, 6, 1, 11),
(3695, '2020-02-11', 2020, 1, 2, 6, 2, 12),
(3696, '2020-02-12', 2020, 1, 2, 6, 3, 13),
(3697, '2020-02-13', 2020, 1, 2, 6, 4, 14),
(3698, '2020-02-14', 2020, 1, 2, 6, 5, 15),
(3699, '2020-02-15', 2020, 1, 2, 7, 6, 16),
(3700, '2020-02-16', 2020, 1, 2, 7, 0, 17),
(3701, '2020-02-17', 2020, 1, 2, 7, 1, 18),
(3702, '2020-02-18', 2020, 1, 2, 7, 2, 19),
(3703, '2020-02-19', 2020, 1, 2, 7, 3, 20),
(3704, '2020-02-20', 2020, 1, 2, 7, 4, 21),
(3705, '2020-02-21', 2020, 1, 2, 7, 5, 22),
(3706, '2020-02-22', 2020, 1, 2, 8, 6, 23),
(3707, '2020-02-23', 2020, 1, 2, 8, 0, 24),
(3708, '2020-02-24', 2020, 1, 2, 8, 1, 25),
(3709, '2020-02-25', 2020, 1, 2, 8, 2, 26),
(3710, '2020-02-26', 2020, 1, 2, 8, 3, 27),
(3711, '2020-02-27', 2020, 1, 2, 8, 4, 28),
(3712, '2020-02-28', 2020, 1, 2, 8, 5, 29),
(3713, '2020-02-29', 2020, 1, 3, 9, 6, 1),
(3714, '2020-03-01', 2020, 1, 3, 9, 0, 2),
(3715, '2020-03-02', 2020, 1, 3, 9, 1, 3),
(3716, '2020-03-03', 2020, 1, 3, 9, 2, 4),
(3717, '2020-03-04', 2020, 1, 3, 9, 3, 5),
(3718, '2020-03-05', 2020, 1, 3, 9, 4, 6),
(3719, '2020-03-06', 2020, 1, 3, 9, 5, 7),
(3720, '2020-03-07', 2020, 1, 3, 10, 6, 8),
(3721, '2020-03-08', 2020, 1, 3, 10, 0, 9),
(3722, '2020-03-09', 2020, 1, 3, 10, 1, 10),
(3723, '2020-03-10', 2020, 1, 3, 10, 2, 11),
(3724, '2020-03-11', 2020, 1, 3, 10, 3, 12),
(3725, '2020-03-12', 2020, 1, 3, 10, 4, 13),
(3726, '2020-03-13', 2020, 1, 3, 10, 5, 14),
(3727, '2020-03-14', 2020, 1, 3, 11, 6, 15),
(3728, '2020-03-15', 2020, 1, 3, 11, 0, 16),
(3729, '2020-03-16', 2020, 1, 3, 11, 1, 17),
(3730, '2020-03-17', 2020, 1, 3, 11, 2, 18),
(3731, '2020-03-18', 2020, 1, 3, 11, 3, 19),
(3732, '2020-03-19', 2020, 1, 3, 11, 4, 20),
(3733, '2020-03-20', 2020, 1, 3, 11, 5, 21),
(3734, '2020-03-21', 2020, 1, 3, 12, 6, 22),
(3735, '2020-03-22', 2020, 1, 3, 12, 0, 23),
(3736, '2020-03-23', 2020, 1, 3, 12, 1, 24),
(3737, '2020-03-24', 2020, 1, 3, 12, 2, 25),
(3738, '2020-03-25', 2020, 1, 3, 12, 3, 26),
(3739, '2020-03-26', 2020, 1, 3, 12, 4, 27),
(3740, '2020-03-27', 2020, 1, 3, 12, 5, 28),
(3741, '2020-03-28', 2020, 1, 3, 13, 6, 29),
(3742, '2020-03-29', 2020, 1, 3, 13, 0, 30),
(3743, '2020-03-30', 2020, 1, 3, 13, 1, 31),
(3744, '2020-03-31', 2020, 2, 4, 13, 2, 1),
(3745, '2020-04-01', 2020, 2, 4, 13, 3, 2),
(3746, '2020-04-02', 2020, 2, 4, 13, 4, 3),
(3747, '2020-04-03', 2020, 2, 4, 13, 5, 4),
(3748, '2020-04-04', 2020, 2, 4, 14, 6, 5),
(3749, '2020-04-05', 2020, 2, 4, 14, 0, 6),
(3750, '2020-04-06', 2020, 2, 4, 14, 1, 7),
(3751, '2020-04-07', 2020, 2, 4, 14, 2, 8),
(3752, '2020-04-08', 2020, 2, 4, 14, 3, 9),
(3753, '2020-04-09', 2020, 2, 4, 14, 4, 10),
(3754, '2020-04-10', 2020, 2, 4, 14, 5, 11),
(3755, '2020-04-11', 2020, 2, 4, 15, 6, 12),
(3756, '2020-04-12', 2020, 2, 4, 15, 0, 13),
(3757, '2020-04-13', 2020, 2, 4, 15, 1, 14),
(3758, '2020-04-14', 2020, 2, 4, 15, 2, 15),
(3759, '2020-04-15', 2020, 2, 4, 15, 3, 16),
(3760, '2020-04-16', 2020, 2, 4, 15, 4, 17),
(3761, '2020-04-17', 2020, 2, 4, 15, 5, 18),
(3762, '2020-04-18', 2020, 2, 4, 16, 6, 19),
(3763, '2020-04-19', 2020, 2, 4, 16, 0, 20),
(3764, '2020-04-20', 2020, 2, 4, 16, 1, 21),
(3765, '2020-04-21', 2020, 2, 4, 16, 2, 22),
(3766, '2020-04-22', 2020, 2, 4, 16, 3, 23),
(3767, '2020-04-23', 2020, 2, 4, 16, 4, 24),
(3768, '2020-04-24', 2020, 2, 4, 16, 5, 25),
(3769, '2020-04-25', 2020, 2, 4, 17, 6, 26),
(3770, '2020-04-26', 2020, 2, 4, 17, 0, 27),
(3771, '2020-04-27', 2020, 2, 4, 17, 1, 28),
(3772, '2020-04-28', 2020, 2, 4, 17, 2, 29),
(3773, '2020-04-29', 2020, 2, 4, 17, 3, 30),
(3774, '2020-04-30', 2020, 2, 5, 17, 4, 1),
(3775, '2020-05-01', 2020, 2, 5, 17, 5, 2),
(3776, '2020-05-02', 2020, 2, 5, 18, 6, 3),
(3777, '2020-05-03', 2020, 2, 5, 18, 0, 4),
(3778, '2020-05-04', 2020, 2, 5, 18, 1, 5),
(3779, '2020-05-05', 2020, 2, 5, 18, 2, 6),
(3780, '2020-05-06', 2020, 2, 5, 18, 3, 7),
(3781, '2020-05-07', 2020, 2, 5, 18, 4, 8),
(3782, '2020-05-08', 2020, 2, 5, 18, 5, 9),
(3783, '2020-05-09', 2020, 2, 5, 19, 6, 10),
(3784, '2020-05-10', 2020, 2, 5, 19, 0, 11),
(3785, '2020-05-11', 2020, 2, 5, 19, 1, 12),
(3786, '2020-05-12', 2020, 2, 5, 19, 2, 13),
(3787, '2020-05-13', 2020, 2, 5, 19, 3, 14),
(3788, '2020-05-14', 2020, 2, 5, 19, 4, 15),
(3789, '2020-05-15', 2020, 2, 5, 19, 5, 16),
(3790, '2020-05-16', 2020, 2, 5, 20, 6, 17),
(3791, '2020-05-17', 2020, 2, 5, 20, 0, 18),
(3792, '2020-05-18', 2020, 2, 5, 20, 1, 19),
(3793, '2020-05-19', 2020, 2, 5, 20, 2, 20),
(3794, '2020-05-20', 2020, 2, 5, 20, 3, 21),
(3795, '2020-05-21', 2020, 2, 5, 20, 4, 22),
(3796, '2020-05-22', 2020, 2, 5, 20, 5, 23),
(3797, '2020-05-23', 2020, 2, 5, 21, 6, 24),
(3798, '2020-05-24', 2020, 2, 5, 21, 0, 25),
(3799, '2020-05-25', 2020, 2, 5, 21, 1, 26),
(3800, '2020-05-26', 2020, 2, 5, 21, 2, 27),
(3801, '2020-05-27', 2020, 2, 5, 21, 3, 28),
(3802, '2020-05-28', 2020, 2, 5, 21, 4, 29),
(3803, '2020-05-29', 2020, 2, 5, 21, 5, 30),
(3804, '2020-05-30', 2020, 2, 5, 22, 6, 31),
(3805, '2020-05-31', 2020, 2, 6, 22, 0, 1),
(3806, '2020-06-01', 2020, 2, 6, 22, 1, 2),
(3807, '2020-06-02', 2020, 2, 6, 22, 2, 3),
(3808, '2020-06-03', 2020, 2, 6, 22, 3, 4),
(3809, '2020-06-04', 2020, 2, 6, 22, 4, 5),
(3810, '2020-06-05', 2020, 2, 6, 22, 5, 6),
(3811, '2020-06-06', 2020, 2, 6, 23, 6, 7),
(3812, '2020-06-07', 2020, 2, 6, 23, 0, 8),
(3813, '2020-06-08', 2020, 2, 6, 23, 1, 9),
(3814, '2020-06-09', 2020, 2, 6, 23, 2, 10),
(3815, '2020-06-10', 2020, 2, 6, 23, 3, 11),
(3816, '2020-06-11', 2020, 2, 6, 23, 4, 12),
(3817, '2020-06-12', 2020, 2, 6, 23, 5, 13),
(3818, '2020-06-13', 2020, 2, 6, 24, 6, 14),
(3819, '2020-06-14', 2020, 2, 6, 24, 0, 15),
(3820, '2020-06-15', 2020, 2, 6, 24, 1, 16),
(3821, '2020-06-16', 2020, 2, 6, 24, 2, 17),
(3822, '2020-06-17', 2020, 2, 6, 24, 3, 18),
(3823, '2020-06-18', 2020, 2, 6, 24, 4, 19),
(3824, '2020-06-19', 2020, 2, 6, 24, 5, 20),
(3825, '2020-06-20', 2020, 2, 6, 25, 6, 21),
(3826, '2020-06-21', 2020, 2, 6, 25, 0, 22),
(3827, '2020-06-22', 2020, 2, 6, 25, 1, 23),
(3828, '2020-06-23', 2020, 2, 6, 25, 2, 24),
(3829, '2020-06-24', 2020, 2, 6, 25, 3, 25),
(3830, '2020-06-25', 2020, 2, 6, 25, 4, 26),
(3831, '2020-06-26', 2020, 2, 6, 25, 5, 27),
(3832, '2020-06-27', 2020, 2, 6, 26, 6, 28),
(3833, '2020-06-28', 2020, 2, 6, 26, 0, 29),
(3834, '2020-06-29', 2020, 2, 6, 26, 1, 30),
(3835, '2020-06-30', 2020, 3, 7, 26, 2, 1),
(3836, '2020-07-01', 2020, 3, 7, 26, 3, 2),
(3837, '2020-07-02', 2020, 3, 7, 26, 4, 3),
(3838, '2020-07-03', 2020, 3, 7, 26, 5, 4),
(3839, '2020-07-04', 2020, 3, 7, 27, 6, 5),
(3840, '2020-07-05', 2020, 3, 7, 27, 0, 6),
(3841, '2020-07-06', 2020, 3, 7, 27, 1, 7),
(3842, '2020-07-07', 2020, 3, 7, 27, 2, 8),
(3843, '2020-07-08', 2020, 3, 7, 27, 3, 9),
(3844, '2020-07-09', 2020, 3, 7, 27, 4, 10),
(3845, '2020-07-10', 2020, 3, 7, 27, 5, 11),
(3846, '2020-07-11', 2020, 3, 7, 28, 6, 12),
(3847, '2020-07-12', 2020, 3, 7, 28, 0, 13),
(3848, '2020-07-13', 2020, 3, 7, 28, 1, 14),
(3849, '2020-07-14', 2020, 3, 7, 28, 2, 15),
(3850, '2020-07-15', 2020, 3, 7, 28, 3, 16),
(3851, '2020-07-16', 2020, 3, 7, 28, 4, 17),
(3852, '2020-07-17', 2020, 3, 7, 28, 5, 18),
(3853, '2020-07-18', 2020, 3, 7, 29, 6, 19),
(3854, '2020-07-19', 2020, 3, 7, 29, 0, 20),
(3855, '2020-07-20', 2020, 3, 7, 29, 1, 21),
(3856, '2020-07-21', 2020, 3, 7, 29, 2, 22),
(3857, '2020-07-22', 2020, 3, 7, 29, 3, 23),
(3858, '2020-07-23', 2020, 3, 7, 29, 4, 24),
(3859, '2020-07-24', 2020, 3, 7, 29, 5, 25),
(3860, '2020-07-25', 2020, 3, 7, 30, 6, 26),
(3861, '2020-07-26', 2020, 3, 7, 30, 0, 27),
(3862, '2020-07-27', 2020, 3, 7, 30, 1, 28),
(3863, '2020-07-28', 2020, 3, 7, 30, 2, 29),
(3864, '2020-07-29', 2020, 3, 7, 30, 3, 30),
(3865, '2020-07-30', 2020, 3, 7, 30, 4, 31),
(3866, '2020-07-31', 2020, 3, 8, 30, 5, 1),
(3867, '2020-08-01', 2020, 3, 8, 31, 6, 2),
(3868, '2020-08-02', 2020, 3, 8, 31, 0, 3),
(3869, '2020-08-03', 2020, 3, 8, 31, 1, 4),
(3870, '2020-08-04', 2020, 3, 8, 31, 2, 5),
(3871, '2020-08-05', 2020, 3, 8, 31, 3, 6),
(3872, '2020-08-06', 2020, 3, 8, 31, 4, 7),
(3873, '2020-08-07', 2020, 3, 8, 31, 5, 8),
(3874, '2020-08-08', 2020, 3, 8, 32, 6, 9),
(3875, '2020-08-09', 2020, 3, 8, 32, 0, 10),
(3876, '2020-08-10', 2020, 3, 8, 32, 1, 11),
(3877, '2020-08-11', 2020, 3, 8, 32, 2, 12),
(3878, '2020-08-12', 2020, 3, 8, 32, 3, 13),
(3879, '2020-08-13', 2020, 3, 8, 32, 4, 14),
(3880, '2020-08-14', 2020, 3, 8, 32, 5, 15),
(3881, '2020-08-15', 2020, 3, 8, 33, 6, 16),
(3882, '2020-08-16', 2020, 3, 8, 33, 0, 17),
(3883, '2020-08-17', 2020, 3, 8, 33, 1, 18),
(3884, '2020-08-18', 2020, 3, 8, 33, 2, 19),
(3885, '2020-08-19', 2020, 3, 8, 33, 3, 20),
(3886, '2020-08-20', 2020, 3, 8, 33, 4, 21),
(3887, '2020-08-21', 2020, 3, 8, 33, 5, 22),
(3888, '2020-08-22', 2020, 3, 8, 34, 6, 23),
(3889, '2020-08-23', 2020, 3, 8, 34, 0, 24),
(3890, '2020-08-24', 2020, 3, 8, 34, 1, 25),
(3891, '2020-08-25', 2020, 3, 8, 34, 2, 26),
(3892, '2020-08-26', 2020, 3, 8, 34, 3, 27),
(3893, '2020-08-27', 2020, 3, 8, 34, 4, 28),
(3894, '2020-08-28', 2020, 3, 8, 34, 5, 29),
(3895, '2020-08-29', 2020, 3, 8, 35, 6, 30),
(3896, '2020-08-30', 2020, 3, 8, 35, 0, 31),
(3897, '2020-08-31', 2020, 3, 9, 35, 1, 1),
(3898, '2020-09-01', 2020, 3, 9, 35, 2, 2),
(3899, '2020-09-02', 2020, 3, 9, 35, 3, 3),
(3900, '2020-09-03', 2020, 3, 9, 35, 4, 4),
(3901, '2020-09-04', 2020, 3, 9, 35, 5, 5),
(3902, '2020-09-05', 2020, 3, 9, 36, 6, 6),
(3903, '2020-09-06', 2020, 3, 9, 36, 0, 7),
(3904, '2020-09-07', 2020, 3, 9, 36, 1, 8),
(3905, '2020-09-08', 2020, 3, 9, 36, 2, 9),
(3906, '2020-09-09', 2020, 3, 9, 36, 3, 10),
(3907, '2020-09-10', 2020, 3, 9, 36, 4, 11),
(3908, '2020-09-11', 2020, 3, 9, 36, 5, 12),
(3909, '2020-09-12', 2020, 3, 9, 37, 6, 13),
(3910, '2020-09-13', 2020, 3, 9, 37, 0, 14),
(3911, '2020-09-14', 2020, 3, 9, 37, 1, 15),
(3912, '2020-09-15', 2020, 3, 9, 37, 2, 16),
(3913, '2020-09-16', 2020, 3, 9, 37, 3, 17),
(3914, '2020-09-17', 2020, 3, 9, 37, 4, 18),
(3915, '2020-09-18', 2020, 3, 9, 37, 5, 19),
(3916, '2020-09-19', 2020, 3, 9, 38, 6, 20),
(3917, '2020-09-20', 2020, 3, 9, 38, 0, 21),
(3918, '2020-09-21', 2020, 3, 9, 38, 1, 22),
(3919, '2020-09-22', 2020, 3, 9, 38, 2, 23),
(3920, '2020-09-23', 2020, 3, 9, 38, 3, 24),
(3921, '2020-09-24', 2020, 3, 9, 38, 4, 25),
(3922, '2020-09-25', 2020, 3, 9, 38, 5, 26),
(3923, '2020-09-26', 2020, 3, 9, 39, 6, 27),
(3924, '2020-09-27', 2020, 3, 9, 39, 0, 28),
(3925, '2020-09-28', 2020, 3, 9, 39, 1, 29),
(3926, '2020-09-29', 2020, 3, 9, 39, 2, 30),
(3927, '2020-09-30', 2020, 4, 10, 39, 3, 1),
(3928, '2020-10-01', 2020, 4, 10, 39, 4, 2),
(3929, '2020-10-02', 2020, 4, 10, 39, 5, 3),
(3930, '2020-10-03', 2020, 4, 10, 40, 6, 4),
(3931, '2020-10-04', 2020, 4, 10, 40, 0, 5),
(3932, '2020-10-05', 2020, 4, 10, 40, 1, 6),
(3933, '2020-10-06', 2020, 4, 10, 40, 2, 7),
(3934, '2020-10-07', 2020, 4, 10, 40, 3, 8),
(3935, '2020-10-08', 2020, 4, 10, 40, 4, 9),
(3936, '2020-10-09', 2020, 4, 10, 40, 5, 10),
(3937, '2020-10-10', 2020, 4, 10, 41, 6, 11),
(3938, '2020-10-11', 2020, 4, 10, 41, 0, 12),
(3939, '2020-10-12', 2020, 4, 10, 41, 1, 13),
(3940, '2020-10-13', 2020, 4, 10, 41, 2, 14),
(3941, '2020-10-14', 2020, 4, 10, 41, 3, 15),
(3942, '2020-10-15', 2020, 4, 10, 41, 4, 16),
(3943, '2020-10-16', 2020, 4, 10, 41, 5, 17),
(3944, '2020-10-17', 2020, 4, 10, 42, 6, 18),
(3945, '2020-10-18', 2020, 4, 10, 42, 0, 19),
(3946, '2020-10-19', 2020, 4, 10, 42, 1, 20),
(3947, '2020-10-20', 2020, 4, 10, 42, 2, 21),
(3948, '2020-10-21', 2020, 4, 10, 42, 3, 22),
(3949, '2020-10-22', 2020, 4, 10, 42, 4, 23),
(3950, '2020-10-23', 2020, 4, 10, 42, 5, 24),
(3951, '2020-10-24', 2020, 4, 10, 43, 6, 25),
(3952, '2020-10-25', 2020, 4, 10, 43, 0, 26),
(3953, '2020-10-26', 2020, 4, 10, 43, 1, 27),
(3954, '2020-10-27', 2020, 4, 10, 43, 2, 28),
(3955, '2020-10-28', 2020, 4, 10, 43, 3, 29),
(3956, '2020-10-29', 2020, 4, 10, 43, 4, 30),
(3957, '2020-10-30', 2020, 4, 10, 43, 5, 31),
(3958, '2020-10-31', 2020, 4, 11, 44, 6, 1),
(3959, '2020-11-01', 2020, 4, 11, 44, 0, 2),
(3960, '2020-11-02', 2020, 4, 11, 44, 1, 3),
(3961, '2020-11-03', 2020, 4, 11, 44, 2, 4),
(3962, '2020-11-04', 2020, 4, 11, 44, 3, 5),
(3963, '2020-11-05', 2020, 4, 11, 44, 4, 6),
(3964, '2020-11-06', 2020, 4, 11, 44, 5, 7),
(3965, '2020-11-07', 2020, 4, 11, 45, 6, 8),
(3966, '2020-11-08', 2020, 4, 11, 45, 0, 9),
(3967, '2020-11-09', 2020, 4, 11, 45, 1, 10),
(3968, '2020-11-10', 2020, 4, 11, 45, 2, 11),
(3969, '2020-11-11', 2020, 4, 11, 45, 3, 12),
(3970, '2020-11-12', 2020, 4, 11, 45, 4, 13),
(3971, '2020-11-13', 2020, 4, 11, 45, 5, 14),
(3972, '2020-11-14', 2020, 4, 11, 46, 6, 15),
(3973, '2020-11-15', 2020, 4, 11, 46, 0, 16),
(3974, '2020-11-16', 2020, 4, 11, 46, 1, 17),
(3975, '2020-11-17', 2020, 4, 11, 46, 2, 18),
(3976, '2020-11-18', 2020, 4, 11, 46, 3, 19),
(3977, '2020-11-19', 2020, 4, 11, 46, 4, 20),
(3978, '2020-11-20', 2020, 4, 11, 46, 5, 21),
(3979, '2020-11-21', 2020, 4, 11, 47, 6, 22),
(3980, '2020-11-22', 2020, 4, 11, 47, 0, 23),
(3981, '2020-11-23', 2020, 4, 11, 47, 1, 24),
(3982, '2020-11-24', 2020, 4, 11, 47, 2, 25),
(3983, '2020-11-25', 2020, 4, 11, 47, 3, 26),
(3984, '2020-11-26', 2020, 4, 11, 47, 4, 27),
(3985, '2020-11-27', 2020, 4, 11, 47, 5, 28),
(3986, '2020-11-28', 2020, 4, 11, 48, 6, 29),
(3987, '2020-11-29', 2020, 4, 11, 48, 0, 30),
(3988, '2020-11-30', 2020, 4, 12, 48, 1, 1),
(3989, '2020-12-01', 2020, 4, 12, 48, 2, 2),
(3990, '2020-12-02', 2020, 4, 12, 48, 3, 3),
(3991, '2020-12-03', 2020, 4, 12, 48, 4, 4),
(3992, '2020-12-04', 2020, 4, 12, 48, 5, 5),
(3993, '2020-12-05', 2020, 4, 12, 49, 6, 6),
(3994, '2020-12-06', 2020, 4, 12, 49, 0, 7),
(3995, '2020-12-07', 2020, 4, 12, 49, 1, 8),
(3996, '2020-12-08', 2020, 4, 12, 49, 2, 9),
(3997, '2020-12-09', 2020, 4, 12, 49, 3, 10),
(3998, '2020-12-10', 2020, 4, 12, 49, 4, 11),
(3999, '2020-12-11', 2020, 4, 12, 49, 5, 12),
(4000, '2020-12-12', 2020, 4, 12, 50, 6, 13),
(4001, '2020-12-13', 2020, 4, 12, 50, 0, 14),
(4002, '2020-12-14', 2020, 4, 12, 50, 1, 15),
(4003, '2020-12-15', 2020, 4, 12, 50, 2, 16),
(4004, '2020-12-16', 2020, 4, 12, 50, 3, 17),
(4005, '2020-12-17', 2020, 4, 12, 50, 4, 18),
(4006, '2020-12-18', 2020, 4, 12, 50, 5, 19),
(4007, '2020-12-19', 2020, 4, 12, 51, 6, 20),
(4008, '2020-12-20', 2020, 4, 12, 51, 0, 21),
(4009, '2020-12-21', 2020, 4, 12, 51, 1, 22),
(4010, '2020-12-22', 2020, 4, 12, 51, 2, 23),
(4011, '2020-12-23', 2020, 4, 12, 51, 3, 24),
(4012, '2020-12-24', 2020, 4, 12, 51, 4, 25),
(4013, '2020-12-25', 2020, 4, 12, 51, 5, 26),
(4014, '2020-12-26', 2020, 4, 12, 52, 6, 27),
(4015, '2020-12-27', 2020, 4, 12, 52, 0, 28),
(4016, '2020-12-28', 2020, 4, 12, 52, 1, 29),
(4017, '2020-12-29', 2020, 4, 12, 52, 2, 30),
(4018, '2020-12-30', 2020, 4, 12, 52, 3, 31);

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_devicebrand`
--

CREATE TABLE IF NOT EXISTS `razor_dim_devicebrand` (
  `devicebrand_sk` int(11) NOT NULL,
  `devicebrand_name` varchar(60) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_devicelanguage`
--

CREATE TABLE IF NOT EXISTS `razor_dim_devicelanguage` (
  `devicelanguage_sk` int(11) NOT NULL,
  `devicelanguage_name` varchar(60) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_deviceos`
--

CREATE TABLE IF NOT EXISTS `razor_dim_deviceos` (
  `deviceos_sk` int(11) NOT NULL,
  `deviceos_name` varchar(256) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_deviceresolution`
--

CREATE TABLE IF NOT EXISTS `razor_dim_deviceresolution` (
  `deviceresolution_sk` int(11) NOT NULL,
  `deviceresolution_name` varchar(60) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_devicesupplier`
--

CREATE TABLE IF NOT EXISTS `razor_dim_devicesupplier` (
  `devicesupplier_sk` int(11) NOT NULL,
  `mccmnc` varchar(16) NOT NULL,
  `devicesupplier_name` varchar(128) NOT NULL DEFAULT 'unknown',
  `countrycode` varchar(8) DEFAULT NULL,
  `countryname` varchar(128) DEFAULT NULL
) ENGINE=InnoDB AUTO_INCREMENT=1068 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_dim_devicesupplier`
--

INSERT INTO `razor_dim_devicesupplier` (`devicesupplier_sk`, `mccmnc`, `devicesupplier_name`, `countrycode`, `countryname`) VALUES
(1, '20201', 'Cosmote Greece', '202', 'GR'),
(2, '20205', 'Vodafone - Panafon Greece', '202', 'GR'),
(3, '20209', 'Info Quest S.A. Greece', '202', 'GR'),
(4, '20210', 'Telestet Greece', '202', 'GR'),
(5, '20402', 'Tele2 (Netherlands) B.V.', '204', 'NL'),
(6, '20404', 'Vodafone Libertel N.V. Netherlands', '204', 'NL'),
(7, '20408', 'KPN Telecom B.V. Netherlands', '204', 'NL'),
(8, '20412', 'BT Ignite Nederland B.V.', '204', 'NL'),
(9, '20416', 'BEN Nederland B.V.', '204', 'NL'),
(10, '20420', 'Dutchtone N.V. Netherlands', '204', 'NL'),
(11, '20421', 'NS Railinfrabeheer B.V. Netherlands', '204', 'NL'),
(12, '20601', 'Proximus Belgium', '206', 'BE'),
(13, '20610', 'Mobistar Belgium', '206', 'BE'),
(14, '20620', 'Base Belgium', '206', 'BE'),
(15, '20801', 'Orange', '208', 'FR'),
(16, '20802', 'Orange', '208', 'FR'),
(17, '20805', 'Globalstar Europe France', '208', 'FR'),
(18, '20806', 'Globalstar Europe France', '208', 'FR'),
(19, '20807', 'Globalstar Europe France', '208', 'FR'),
(20, '20810', 'SFR', '208', 'FR'),
(21, '20811', 'SFR', '208', 'FR'),
(22, '20813', 'SFR', '208', 'FR'),
(23, '20815', 'Free Mobile', '208', 'FR'),
(24, '20816', 'Free Mobile', '208', 'FR'),
(25, '20820', 'Bouygues Telecom', '208', 'FR'),
(26, '20821', 'Bouygues Telecom', '208', 'FR'),
(27, '20823', 'Virgin Mobile', '208', 'FR'),
(28, '20825', 'Lycamobile', '208', 'FR'),
(29, '20826', 'NRJ Mobile', '208', 'FR'),
(30, '20827', 'Afone Mobile', '208', 'FR'),
(31, '20830', 'Symacom', '208', 'FR'),
(32, '20888', 'Bouygues Telecom', '208', 'FR'),
(33, '21303', 'MobilandAndorra', '213', 'AD'),
(34, '21401', 'Vodafone Spain', '214', 'ES'),
(35, '21403', 'Amena Spain', '214', 'ES'),
(36, '21404', 'Xfera Spain', '214', 'ES'),
(37, '21407', 'Movistar Spain', '214', 'ES'),
(38, '21601', 'Pannon GSM Hungary', '216', 'HU'),
(39, '21630', 'T-Mobile Hungary', '216', 'HU'),
(40, '21670', 'Vodafone Hungary', '216', 'HU'),
(41, '21803', 'Eronet Mobile Communications Ltd. Bosnia and Herzegovina', '218', 'BA'),
(42, '21805', 'MOBIS (Mobilina Srpske) Bosnia and Herzegovina', '218', 'BA'),
(43, '21890', 'GSMBIH Bosnia and Herzegovina', '218', 'BA'),
(44, '21901', 'Cronet Croatia', '219', 'HR'),
(45, '21910', 'VIPnet Croatia', '219', 'HR'),
(46, '22001', 'Mobtel Serbia', '220', 'YU'),
(47, '22002', 'Promonte GSM Serbia', '220', 'YU'),
(48, '22003', 'Telekom Srbija', '220', 'YU'),
(49, '22004', 'Monet Serbia', '220', 'YU'),
(50, '22201', 'Telecom Italia Mobile (TIM)', '222', 'IT'),
(51, '22202', 'Elsacom Italy', '222', 'IT'),
(52, '22210', 'Omnitel Pronto Italia (OPI)', '222', 'IT'),
(53, '22277', 'IPSE 2000 Italy', '222', 'IT'),
(54, '22288', 'Wind Italy', '222', 'IT'),
(55, '22298', 'Blu Italy', '222', 'IT'),
(56, '22299', 'H3G Italy', '222', 'IT'),
(57, '22601', 'Vodafone Romania SA', '226', 'RO'),
(58, '22603', 'Cosmorom Romania', '226', 'RO'),
(59, '22610', 'Orange Romania', '226', 'RO'),
(60, '22801', 'Swisscom GSM', '228', 'CH'),
(61, '22802', 'Sunrise GSM Switzerland', '228', 'CH'),
(62, '22803', 'Orange Switzerland', '228', 'CH'),
(63, '22805', 'Togewanet AG Switzerland', '228', 'CH'),
(64, '22806', 'SBB AG Switzerland', '228', 'CH'),
(65, '22807', 'IN&Phone SA Switzerland', '228', 'CH'),
(66, '22808', 'Tele2 Telecommunications AG Switzerland', '228', 'CH'),
(67, '22812', 'Sunrise UMTS Switzerland', '228', 'CH'),
(68, '22850', '3G Mabile AG Switzerland', '228', 'CH'),
(69, '22851', 'Global Networks Schweiz AG', '228', 'CH'),
(70, '23001', 'RadioMobil a.s., T-Mobile Czech Rep.', '230', 'CZ'),
(71, '23002', 'Eurotel Praha, spol. Sro., Eurotel Czech Rep.', '230', 'CZ'),
(72, '23003', 'Cesky Mobil a.s., Oskar', '230', 'CZ'),
(73, '23099', 'Cesky Mobil a.s., R&D Centre', '230', 'CZ'),
(74, '23101', 'Orange, GSM Slovakia', '231', 'SK'),
(75, '23102', 'Eurotel, GSM & NMT Slovakia', '231', 'SK'),
(76, '23104', 'Eurotel, UMTS Slovakia', '231', 'SK'),
(77, '23105', 'Orange, UMTS Slovakia', '231', 'SK'),
(78, '23201', 'A1 Austria', '232', 'AT'),
(79, '23203', 'T-Mobile Austria', '232', 'AT'),
(80, '23205', 'One Austria', '232', 'AT'),
(81, '23207', 'tele.ring Austria', '232', 'AT'),
(82, '23208', 'Telefonica Austria', '232', 'AT'),
(83, '23209', 'One Austria', '232', 'AT'),
(84, '23210', 'Hutchison 3G Austria', '232', 'AT'),
(85, '23402', 'O2 UK Ltd.', '234', 'GB'),
(86, '23410', 'O2 UK Ltd.', '234', 'GB'),
(87, '23411', 'O2 UK Ltd.', '234', 'GB'),
(88, '23412', 'Railtrack Plc UK', '234', 'GB'),
(89, '23415', 'Vodafone', '234', 'GB'),
(90, '23420', 'Hutchison 3G UK Ltd.', '234', 'GB'),
(91, '23430', 'T-Mobile UK', '234', 'GB'),
(92, '23431', 'T-Mobile UK', '234', 'GB'),
(93, '23432', 'T-Mobile UK', '234', 'GB'),
(94, '23433', 'Orange UK', '234', 'GB'),
(95, '23434', 'Orange UK', '234', 'GB'),
(96, '23450', 'Jersey Telecom UK', '234', 'GB'),
(97, '23455', 'Guensey Telecom UK', '234', 'GB'),
(98, '23458', 'Manx Telecom UK', '234', 'GB'),
(99, '23475', 'Inquam Telecom (Holdings) Ltd. UK', '234', 'GB'),
(100, '23801', 'TDC Mobil Denmark', '238', 'DK'),
(101, '23802', 'Sonofon Denmark', '238', 'DK'),
(102, '23803', 'MIGway A/S Denmark', '238', 'DK'),
(103, '23806', 'Hi3G Denmark', '238', 'DK'),
(104, '23807', 'Barablu Mobile Ltd. Denmark', '238', 'DK'),
(105, '23810', 'TDC Mobil Denmark', '238', 'DK'),
(106, '23820', 'Telia Denmark', '238', 'DK'),
(107, '23830', 'Telia Mobile Denmark', '238', 'DK'),
(108, '23877', 'Tele2 Denmark', '238', 'DK'),
(109, '24001', 'Telia Sonera AB Sweden', '240', 'SE'),
(110, '24002', 'H3G Access AB Sweden', '240', 'SE'),
(111, '24003', 'Nordisk Mobiltelefon AS Sweden', '240', 'SE'),
(112, '24004', '3G Infrastructure Services AB Sweden', '240', 'SE'),
(113, '24005', 'Svenska UMTS-Nat AB', '240', 'SE'),
(114, '24006', 'Telenor Sverige AB', '240', 'SE'),
(115, '24007', 'Tele2 Sverige AB', '240', 'SE'),
(116, '24008', 'Telenor Sverige AB', '240', 'SE'),
(117, '24009', 'Telenor Mobile Sverige', '240', 'SE'),
(118, '24010', 'Swefour AB Sweden', '240', 'SE'),
(119, '24011', 'Linholmen Science Park AB Sweden', '240', 'SE'),
(120, '24020', 'Wireless Maingate Message Services AB Sweden', '240', 'SE'),
(121, '24021', 'Banverket Sweden', '240', 'SE'),
(122, '24201', 'Telenor Mobil AS Norway', '242', 'NO'),
(123, '24202', 'Netcom GSM AS Norway', '242', 'NO'),
(124, '24203', 'Teletopia Mobile Communications AS Norway', '242', 'NO'),
(125, '24204', 'Tele2 Norge AS', '242', 'NO'),
(126, '24404', 'Finnet Networks Ltd.', '244', 'FI'),
(127, '24405', 'Elisa Matkapuhelinpalvelut Ltd. Finland', '244', 'FI'),
(128, '24409', 'Finnet Group', '244', 'FI'),
(129, '24412', 'Finnet Networks Ltd.', '244', 'FI'),
(130, '24414', 'Alands Mobiltelefon AB Finland', '244', 'FI'),
(131, '24416', 'Oy Finland Tele2 AB', '244', 'FI'),
(132, '24421', 'Saunalahti Group Ltd. Finland', '244', 'FI'),
(133, '24491', 'Sonera Carrier Networks Oy Finland', '244', 'FI'),
(134, '24601', 'Omnitel Lithuania', '246', 'LT'),
(135, '24602', 'Bit GSM Lithuania', '246', 'LT'),
(136, '24603', 'Tele2 Lithuania', '246', 'LT'),
(137, '24701', 'Latvian Mobile Phone', '247', 'LV'),
(138, '24702', 'Tele2 Latvia', '247', 'LV'),
(139, '24703', 'Telekom Baltija Latvia', '247', 'LV'),
(140, '24704', 'Beta Telecom Latvia', '247', 'LV'),
(141, '24801', 'EMT GSM Estonia', '248', 'EE'),
(142, '24802', 'RLE Estonia', '248', 'EE'),
(143, '24803', 'Tele2 Estonia', '248', 'EE'),
(144, '24804', 'OY Top Connect Estonia', '248', 'EE'),
(145, '24805', 'AS Bravocom Mobiil Estonia', '248', 'EE'),
(146, '24806', 'OY ViaTel Estonia', '248', 'EE'),
(147, '25001', 'Mobile Telesystems Russia', '250', 'RU'),
(148, '25002', 'Megafon Russia', '250', 'RU'),
(149, '25003', 'Nizhegorodskaya Cellular Communications Russia', '250', 'RU'),
(150, '25004', 'Sibchallenge Russia', '250', 'RU'),
(151, '25005', 'Mobile Comms System Russia', '250', 'RU'),
(152, '25007', 'BM Telecom Russia', '250', 'RU'),
(153, '25010', 'Don Telecom Russia', '250', 'RU'),
(154, '25011', 'Orensot Russia', '250', 'RU'),
(155, '25012', 'Baykal Westcom Russia', '250', 'RU'),
(156, '25013', 'Kuban GSM Russia', '250', 'RU'),
(157, '25016', 'New Telephone Company Russia', '250', 'RU'),
(158, '25017', 'Ermak RMS Russia', '250', 'RU'),
(159, '25019', 'Volgograd Mobile Russia', '250', 'RU'),
(160, '25020', 'ECC Russia', '250', 'RU'),
(161, '25028', 'Extel Russia', '250', 'RU'),
(162, '25039', 'Uralsvyazinform Russia', '250', 'RU'),
(163, '25044', 'Stuvtelesot Russia', '250', 'RU'),
(164, '25092', 'Printelefone Russia', '250', 'RU'),
(165, '25093', 'Telecom XXI Russia', '250', 'RU'),
(166, '25099', 'Bec Line GSM Russia', '250', 'RU'),
(167, '25501', 'Ukrainian Mobile Communication, UMC', '255', 'UA'),
(168, '25502', 'Ukranian Radio Systems, URS', '255', 'UA'),
(169, '25503', 'Kyivstar Ukraine', '255', 'UA'),
(170, '25504', 'Golden Telecom, GT Ukraine', '255', 'UA'),
(171, '25506', 'Astelit Ukraine', '255', 'UA'),
(172, '25507', 'Ukrtelecom Ukraine', '255', 'UA'),
(173, '25701', 'MDC Velcom Belarus', '257', 'BY'),
(174, '25702', 'MTS Belarus', '257', 'BY'),
(175, '25901', 'Voxtel Moldova', '259', 'MD'),
(176, '25902', 'Moldcell Moldova', '259', 'MD'),
(177, '26001', 'Plus GSM (Polkomtel S.A.) Poland', '260', 'PL'),
(178, '26002', 'ERA GSM (Polska Telefonia Cyfrowa Sp. Z.o.o.)', '260', 'PL'),
(179, '26003', 'Idea (Polska Telefonia Komorkowa Centertel Sp. Z.o.o)', '260', 'PL'),
(180, '26004', 'Tele2 Polska (Tele2 Polska Sp. Z.o.o.)', '260', 'PL'),
(181, '26005', 'IDEA (UMTS)/PTK Centertel sp. Z.o.o. Poland', '260', 'PL'),
(182, '26006', 'Netia Mobile Poland', '260', 'PL'),
(183, '26007', 'Premium internet Poland', '260', 'PL'),
(184, '26008', 'E-Telko Poland', '260', 'PL'),
(185, '26009', 'Telekomunikacja Kolejowa (GSM-R) Poland', '260', 'PL'),
(186, '26010', 'Telefony Opalenickie Poland', '260', 'PL'),
(187, '26201', 'T-Mobile Deutschland GmbH', '262', 'DE'),
(188, '26202', 'Vodafone D2 GmbH Germany', '262', 'DE'),
(189, '26203', 'E-Plus Mobilfunk GmbH & Co. KG Germany', '262', 'DE'),
(190, '26204', 'Vodafone D2 GmbH Germany', '262', 'DE'),
(191, '26205', 'E-Plus Mobilfunk GmbH & Co. KG Germany', '262', 'DE'),
(192, '26206', 'T-Mobile Deutschland GmbH', '262', 'DE'),
(193, '26207', 'O2 (Germany) GmbH & Co. OHG', '262', 'DE'),
(194, '26208', 'O2 (Germany) GmbH & Co. OHG', '262', 'DE'),
(195, '26209', 'Vodafone D2 GmbH Germany', '262', 'DE'),
(196, '26210', 'Arcor AG & Co. Germany', '262', 'DE'),
(197, '26211', 'O2 (Germany) GmbH & Co. OHG', '262', 'DE'),
(198, '26212', 'Dolphin Telecom (Deutschland) GmbH', '262', 'DE'),
(199, '26213', 'Mobilcom Multimedia GmbH Germany', '262', 'DE'),
(200, '26214', 'Group 3G UMTS GmbH (Quam) Germany', '262', 'DE'),
(201, '26215', 'Airdata AG Germany', '262', 'DE'),
(202, '26276', 'Siemens AG, ICMNPGUSTA Germany', '262', 'DE'),
(203, '26277', 'E-Plus Mobilfunk GmbH & Co. KG Germany', '262', 'DE'),
(204, '26601', 'Gibtel GSM Gibraltar', '266', 'GI'),
(205, '26801', 'Vodafone Telecel - Comunicacoes Pessoais, S.A. Portugal', '268', 'PT'),
(206, '26803', 'Optimus - Telecomunicacoes, S.A. Portugal', '268', 'PT'),
(207, '26805', 'Oniway - Inforcomunicacoes, S.A. Portugal', '268', 'PT'),
(208, '26806', 'TMN - Telecomunicacoes Moveis Nacionais, S.A. Portugal', '268', 'PT'),
(209, '27001', 'P&T Luxembourg', '270', 'LU'),
(210, '27077', 'Tango Luxembourg', '270', 'LU'),
(211, '27099', 'Voxmobile S.A. Luxembourg', '270', 'LU'),
(212, '27201', 'Vodafone Ireland Plc', '272', 'IE'),
(213, '27202', 'Digifone mm02 Ltd. Ireland', '272', 'IE'),
(214, '27203', 'Meteor Mobile Communications Ltd. Ireland', '272', 'IE'),
(215, '27207', 'Eircom Ireland', '272', 'IE'),
(216, '27209', 'Clever Communications Ltd. Ireland', '272', 'IE'),
(217, '27401', 'Iceland Telecom Ltd.', '274', 'IS'),
(218, '27402', 'Tal hf Iceland', '274', 'IS'),
(219, '27403', 'Islandssimi GSM ehf Iceland', '274', 'IS'),
(220, '27404', 'IMC Islande ehf', '274', 'IS'),
(221, '27601', 'AMC Albania', '276', 'AL'),
(222, '27602', 'Vodafone Albania', '276', 'AL'),
(223, '27801', 'Vodafone Malta', '278', 'MT'),
(224, '27821', 'go mobile Malta', '278', 'MT'),
(225, '28001', 'CYTA Cyprus', '280', 'CY'),
(226, '28010', 'Scancom (Cyprus) Ltd.', '280', 'CY'),
(227, '28201', 'Geocell Ltd. Georgia', '282', 'GE'),
(228, '28202', 'Magti GSM Ltd. Georgia', '282', 'GE'),
(229, '28203', 'Iberiatel Ltd. Georgia', '282', 'GE'),
(230, '28204', 'Mobitel Ltd. Georgia', '282', 'GE'),
(231, '28301', 'ARMGSM', '283', 'AM'),
(232, '28401', 'M-Tel GSM BG Bulgaria', '284', 'BG'),
(233, '28405', 'Globul Bulgaria', '284', 'BG'),
(234, '28601', 'Turkcell Turkey', '286', 'TR'),
(235, '28602', 'Telsim GSM Turkey', '286', 'TR'),
(236, '28603', 'Aria Turkey', '286', 'TR'),
(237, '28604', 'Aycell Turkey', '286', 'TR'),
(238, '28801', 'Faroese Telecom - GSM', '288', 'FO'),
(239, '28802', 'Kall GSM Faroe Islands', '288', 'FO'),
(240, '29001', 'Tele Greenland', '290', 'GR'),
(241, '29201', 'SMT - San Marino Telecom', '292', 'SM'),
(242, '29340', 'SI Mobil Slovenia', '293', 'SI'),
(243, '29341', 'Mobitel Slovenia', '293', 'SI'),
(244, '29369', 'Akton d.o.o. Slovenia', '293', 'SI'),
(245, '29370', 'Tusmobil d.o.o. Slovenia', '293', 'SI'),
(246, '29401', 'Mobimak Macedonia', '294', 'MK'),
(247, '29402', 'MTS Macedonia', '294', 'MK'),
(248, '29501', 'Telecom FL AG Liechtenstein', '295', 'LI'),
(249, '29502', 'Viag Europlatform AG Liechtenstein', '295', 'LI'),
(250, '29505', 'Mobilkom (Liechstein) AG', '295', 'LI'),
(251, '29577', 'Tele2 AG Liechtenstein', '295', 'LI'),
(252, '30236', 'Clearnet Canada', '302', 'CA'),
(253, '30237', 'Microcell Canada', '302', 'CA'),
(254, '30262', 'Ice Wireless Canada', '302', 'CA'),
(255, '30263', 'Aliant Mobility Canada', '302', 'CA'),
(256, '30264', 'Bell Mobility Canada', '302', 'CA'),
(257, '302656', 'Tbay Mobility Canada', '302', 'CA'),
(258, '30266', 'MTS Mobility Canada', '302', 'CA'),
(259, '30267', 'CityTel Mobility Canada', '302', 'CA'),
(260, '30268', 'Sask Tel Mobility Canada', '302', 'CA'),
(261, '30271', 'Globalstar Canada', '302', 'CA'),
(262, '30272', 'Rogers Wireless Canada', '302', 'CA'),
(263, '30286', 'Telus Mobility Canada', '302', 'CA'),
(264, '30801', 'St. Pierre-et-Miquelon Telecom', '308', 'CA'),
(265, '310010', 'MCI USA', '310', 'US'),
(266, '310012', 'Verizon Wireless USA', '310', 'US'),
(267, '310013', 'Mobile Tel Inc. USA', '310', 'US'),
(268, '310014', 'Testing USA', '310', 'US'),
(269, '310016', 'Cricket Communications USA', '310', 'US'),
(270, '310017', 'North Sight Communications Inc. USA', '310', 'US'),
(271, '310020', 'Union Telephone Company USA', '310', 'US'),
(272, '310030', 'Centennial Communications USA', '310', 'US'),
(273, '310034', 'Nevada Wireless LLC USA', '310', 'US'),
(274, '310040', 'Concho Cellular Telephone Co., Inc. USA', '310', 'US'),
(275, '310050', 'ACS Wireless Inc. USA', '310', 'US'),
(276, '310060', 'Consolidated Telcom USA', '310', 'US'),
(277, '310070', 'Highland Cellular, Inc. USA', '310', 'US'),
(278, '310080', 'Corr Wireless Communications LLC USA', '310', 'US'),
(279, '310090', 'Edge Wireless LLC USA', '310', 'US'),
(280, '310100', 'New Mexico RSA 4 East Ltd. Partnership USA', '310', 'US'),
(281, '310120', 'Sprint USA', '310', 'US'),
(282, '310130', 'Carolina West Wireless USA', '310', 'US'),
(283, '310140', 'GTA Wireless LLC USA', '310', 'US'),
(284, '310150', 'Cingular Wireless USA', '310', 'US'),
(285, '310160', 'T-Mobile USA', '310', 'US'),
(286, '310170', 'Cingular Wireless USA', '310', 'US'),
(287, '310180', 'West Central Wireless USA', '310', 'US'),
(288, '310190', 'Alaska Wireless Communications LLC USA', '310', 'US'),
(289, '310200', 'T-Mobile USA', '310', 'US'),
(290, '310210', 'T-Mobile USA', '310', 'US'),
(291, '310220', 'T-Mobile USA', '310', 'US'),
(292, '310230', 'T-Mobile USA', '310', 'US'),
(293, '310240', 'T-Mobile USA', '310', 'US'),
(294, '310250', 'T-Mobile USA', '310', 'US'),
(295, '310260', 'T-Mobile USA', '310', 'US'),
(296, '310270', 'T-Mobile USA', '310', 'US'),
(297, '310280', 'Contennial Puerto Rio License Corp. USA', '310', 'US'),
(298, '310290', 'Nep Cellcorp Inc. USA', '310', 'US'),
(299, '310300', 'Get Mobile Inc. USA', '310', 'US'),
(300, '310310', 'T-Mobile USA', '310', 'US'),
(301, '310320', 'Bug Tussel Wireless LLC USA', '310', 'US'),
(302, '310330', 'AN Subsidiary LLC USA', '310', 'US'),
(303, '310340', 'High Plains Midwest LLC, dba Wetlink Communications USA', '310', 'US'),
(304, '310350', 'Mohave Cellular L.P. USA', '310', 'US'),
(305, '310360', 'Cellular Network Partnership dba Pioneer Cellular USA', '310', 'US'),
(306, '310370', 'Guamcell Cellular and Paging USA', '310', 'US'),
(307, '310380', 'AT&T Wireless Services Inc. USA', '310', 'US'),
(308, '310390', 'TX-11 Acquistion LLC USA', '310', 'US'),
(309, '310400', 'Wave Runner LLC USA', '310', 'US'),
(310, '310410', 'Cingular Wireless USA', '310', 'US'),
(311, '310420', 'Cincinnati Bell Wireless LLC USA', '310', 'US'),
(312, '310430', 'Alaska Digitel LLC USA', '310', 'US'),
(313, '310440', 'Numerex Corp. USA', '310', 'US'),
(314, '310450', 'North East Cellular Inc. USA', '310', 'US'),
(315, '310460', 'TMP Corporation USA', '310', 'US'),
(316, '310470', 'Guam Wireless Telephone Company USA', '310', 'US'),
(317, '310480', 'Choice Phone LLC USA', '310', 'US'),
(318, '310490', 'Triton PCS USA', '310', 'US'),
(319, '310500', 'Public Service Cellular, Inc. USA', '310', 'US'),
(320, '310510', 'Airtel Wireless LLC USA', '310', 'US'),
(321, '310520', 'VeriSign USA', '310', 'US'),
(322, '310530', 'West Virginia Wireless USA', '310', 'US'),
(323, '310540', 'Oklahoma Western Telephone Company USA', '310', 'US'),
(324, '310560', 'American Cellular Corporation USA', '310', 'US'),
(325, '310570', 'MTPCS LLC USA', '310', 'US'),
(326, '310580', 'PCS ONE USA', '310', 'US'),
(327, '310590', 'Western Wireless Corporation USA', '310', 'US'),
(328, '310600', 'New Cell Inc. dba Cellcom USA', '310', 'US'),
(329, '310610', 'Elkhart Telephone Co. Inc. dba Epic Touch Co. USA', '310', 'US'),
(330, '310620', 'Coleman County Telecommunications Inc. (Trans Texas PCS) USA', '310', 'US'),
(331, '310630', 'Comtel PCS Mainstreet LP USA', '310', 'US'),
(332, '310640', 'Airadigm Communications USA', '310', 'US'),
(333, '310650', 'Jasper Wireless Inc. USA', '310', 'US'),
(334, '310660', 'T-Mobile USA', '310', 'US'),
(335, '310670', 'Northstar USA', '310', 'US'),
(336, '310680', 'Noverr Publishing, Inc. dba NPI Wireless USA', '310', 'US'),
(337, '310690', 'Conestoga Wireless Company USA', '310', 'US'),
(338, '310700', 'Cross Valiant Cellular Partnership USA', '310', 'US'),
(339, '310710', 'Arctic Slopo Telephone Association Cooperative USA', '310', 'US'),
(340, '310720', 'Wireless Solutions International Inc. USA', '310', 'US'),
(341, '310730', 'Sea Mobile USA', '310', 'US'),
(342, '310740', 'Telemetrix Technologies USA', '310', 'US'),
(343, '310750', 'East Kentucky Network LLC dba Appalachian Wireless USA', '310', 'US'),
(344, '310760', 'Panhandle Telecommunications Systems Inc. USA', '310', 'US'),
(345, '310770', 'Iowa Wireless Services LP USA', '310', 'US'),
(346, '310790', 'PinPoint Communications Inc. USA', '310', 'US'),
(347, '310800', 'T-Mobile USA', '310', 'US'),
(348, '310810', 'Brazos Cellular Communications Ltd. USA', '310', 'US'),
(349, '310820', 'Triton PCS License Company LLC USA', '310', 'US'),
(350, '310830', 'Caprock Cellular Ltd. Partnership USA', '310', 'US'),
(351, '310840', 'Edge Mobile LLC USA', '310', 'US'),
(352, '310850', 'Aeris Communications, Inc. USA', '310', 'US'),
(353, '310870', 'Kaplan Telephone Company Inc. USA', '310', 'US'),
(354, '310880', 'Advantage Cellular Systems, Inc. USA', '310', 'US'),
(355, '310890', 'Rural Cellular Corporation USA', '310', 'US'),
(356, '310900', 'Taylor Telecommunications Ltd. USA', '310', 'US'),
(357, '310910', 'Southern IL RSA Partnership dba First Cellular of Southern USA', '310', 'US'),
(358, '310940', 'Poka Lambro Telecommunications Ltd. USA', '310', 'US'),
(359, '310950', 'Texas RSA 1 dba XIT Cellular USA', '310', 'US'),
(360, '310970', 'Globalstar USA', '310', 'US'),
(361, '310980', 'AT&T Wireless Services Inc. USA', '310', 'US'),
(362, '310990', 'Alaska Digitel USA', '310', 'US'),
(363, '311000', 'Mid-Tex Cellular Ltd. USA', '311', 'US'),
(364, '311010', 'Chariton Valley Communications Corp., Inc. USA', '311', 'US'),
(365, '311020', 'Missouri RSA No. 5 Partnership USA', '311', 'US'),
(366, '311030', 'Indigo Wireless, Inc. USA', '311', 'US'),
(367, '311040', 'Commet Wireless, LLC USA', '311', 'US'),
(368, '311070', 'Easterbrooke Cellular Corporation USA', '311', 'US'),
(369, '311080', 'Pine Telephone Company dba Pine Cellular USA', '311', 'US'),
(370, '311090', 'Siouxland PCS USA', '311', 'US'),
(371, '311100', 'High Plains Wireless L.P. USA', '311', 'US'),
(372, '311110', 'High Plains Wireless L.P. USA', '311', 'US'),
(373, '311120', 'Choice Phone LLC USA', '311', 'US'),
(374, '311130', 'Amarillo License L.P. USA', '311', 'US'),
(375, '311140', 'MBO Wireless Inc./Cross Telephone Company USA', '311', 'US'),
(376, '311150', 'Wilkes Cellular Inc. USA', '311', 'US'),
(377, '311160', 'Endless Mountains Wireless, LLC USA', '311', 'US'),
(378, '311180', 'Cingular Wireless, Licensee Pacific Telesis Mobile Services, LLC USA', '311', 'US'),
(379, '311190', 'Cellular Properties Inc. USA', '311', 'US'),
(380, '311200', 'ARINC USA', '311', 'US'),
(381, '311210', 'Farmers Cellular Telephone USA', '311', 'US'),
(382, '311230', 'Cellular South Inc. USA', '311', 'US'),
(383, '311250', 'Wave Runner LLC USA', '311', 'US'),
(384, '311260', 'SLO Cellular Inc. dba CellularOne of San Luis Obispo USA', '311', 'US'),
(385, '311270', 'Alltel Communications Inc. USA', '311', 'US'),
(386, '311271', 'Alltel Communications Inc. USA', '311', 'US'),
(387, '311272', 'Alltel Communications Inc. USA', '311', 'US'),
(388, '311273', 'Alltel Communications Inc. USA', '311', 'US'),
(389, '311274', 'Alltel Communications Inc. USA', '311', 'US'),
(390, '311275', 'Alltel Communications Inc. USA', '311', 'US'),
(391, '311276', 'Alltel Communications Inc. USA', '311', 'US'),
(392, '311277', 'Alltel Communications Inc. USA', '311', 'US'),
(393, '311278', 'Alltel Communications Inc. USA', '311', 'US'),
(394, '311279', 'Alltel Communications Inc. USA', '311', 'US'),
(395, '311280', 'Verizon Wireless USA', '311', 'US'),
(396, '311281', 'Verizon Wireless USA', '311', 'US'),
(397, '311282', 'Verizon Wireless USA', '311', 'US'),
(398, '311283', 'Verizon Wireless USA', '311', 'US'),
(399, '311284', 'Verizon Wireless USA', '311', 'US'),
(400, '311285', 'Verizon Wireless USA', '311', 'US'),
(401, '311286', 'Verizon Wireless USA', '311', 'US'),
(402, '311287', 'Verizon Wireless USA', '311', 'US'),
(403, '311288', 'Verizon Wireless USA', '311', 'US'),
(404, '311289', 'Verizon Wireless USA', '311', 'US'),
(405, '311290', 'Pinpoint Wireless Inc. USA', '311', 'US'),
(406, '311320', 'Commnet Wireless LLC USA', '311', 'US'),
(407, '311340', 'Illinois Valley Cellular USA', '311', 'US'),
(408, '311380', 'New Dimension Wireless Ltd. USA', '311', 'US'),
(409, '311390', 'Midwest Wireless Holdings LLC USA', '311', 'US'),
(410, '311400', 'Salmon PCS LLC USA', '311', 'US'),
(411, '311410', 'Iowa RSA No.2 Ltd Partnership USA', '311', 'US'),
(412, '311420', 'Northwest Missouri Cellular Limited Partnership USA', '311', 'US'),
(413, '311430', 'RSA 1 Limited Partnership dba Cellular 29 Plus USA', '311', 'US'),
(414, '311440', 'Bluegrass Cellular LLC USA', '311', 'US'),
(415, '311450', 'Panhandle Telecommunication Systems Inc. USA', '311', 'US'),
(416, '316010', 'Nextel Communications Inc. USA', '316', 'US'),
(417, '316011', 'Southern Communications Services Inc. USA', '316', 'US'),
(418, '334020', 'Telcel Mexico', '334', 'MX'),
(419, '338020', 'Cable & Wireless Jamaica Ltd.', '338', 'JM'),
(420, '338050', 'Mossel (Jamaica) Ltd.', '338', 'JM'),
(421, '34001', 'Orange Carabe Mobiles Guadeloupe', '340', 'FW'),
(422, '34002', 'Outremer Telecom Guadeloupe', '340', 'FW'),
(423, '34003', 'Saint Martin et Saint Barthelemy Telcell Sarl Guadeloupe', '340', 'FW'),
(424, '34020', 'Bouygues Telecom Caraibe Guadeloupe', '340', 'FW'),
(425, '342600', 'Cable & Wireless (Barbados) Ltd.', '342', 'BB '),
(426, '342820', 'Sunbeach Communications Barbados', '342', 'BB '),
(427, '344030', 'APUA PCS Antigua ', '344', 'AG'),
(428, '344920', 'Cable & Wireless (Antigua)', '344', 'AG'),
(429, '344930', 'AT&T Wireless (Antigua)', '344', 'AG'),
(430, '346140', 'Cable & Wireless (Cayman)', '346', 'KY'),
(431, '348570', 'Caribbean Cellular Telephone, Boatphone Ltd.', '348', 'BVI'),
(432, '35001', 'Telecom', '350', 'BM'),
(433, '36251', 'TELCELL GSM Netherlands Antilles', '362', 'AN'),
(434, '36269', 'CT GSM Netherlands Antilles', '362', 'AN'),
(435, '36291', 'SETEL GSM Netherlands Antilles', '362', 'AN'),
(436, '36301', 'Setar GSM Aruba', '363', 'AW'),
(437, '365010', 'Weblinks Limited Anguilla', '365', 'AI'),
(438, '36801', 'ETECSA Cuba', '368', 'CU'),
(439, '37001', 'Orange Dominicana, S.A.', '370', 'DO'),
(440, '37002', 'Verizon Dominicana S.A.', '370', 'DO'),
(441, '37003', 'Tricom S.A. Dominican Rep.', '370', 'DO'),
(442, '37004', 'CentennialDominicana', '370', 'DO'),
(443, '37201', 'Comcel Haiti', '372', 'HT'),
(444, '37202', 'Digicel Haiti', '372', 'HT'),
(445, '37203', 'Rectel Haiti', '372', 'HT'),
(446, '37412', 'TSTT Mobile Trinidad and Tobago', '374', 'TT'),
(447, '374130', 'Digicel Trinidad and Tobago Ltd.', '374', 'TT'),
(448, '374140', 'LaqTel Ltd. Trinidad and Tobago', '374', 'TT'),
(449, '40001', 'Azercell Limited Liability Joint Venture', '400', 'AZ'),
(450, '40002', 'Bakcell Limited Liability Company Azerbaijan', '400', 'AZ'),
(451, '40003', 'Catel JV Azerbaijan', '400', 'AZ'),
(452, '40004', 'Azerphone LLC', '400', 'AZ'),
(453, '40101', 'Kar-Tel llc Kazakhstan', '401', 'KZ'),
(454, '40102', 'TSC Kazak Telecom Kazakhstan', '401', 'KZ'),
(455, '40211', 'Bhutan Telecom Ltd', '402', 'BT '),
(456, '40217', 'B-Mobile of Bhutan Telecom', '402', 'BT '),
(457, '40401', 'Aircell Digilink India Ltd.,', '404', 'IN'),
(458, '40402', 'Bharti Mobile Ltd. India', '404', 'IN'),
(459, '40403', 'Bharti Telenet Ltd. India', '404', 'IN'),
(460, '40404', 'Idea Cellular Ltd. India', '404', 'IN'),
(461, '40405', 'Fascel Ltd. India', '404', 'IN'),
(462, '40406', 'Bharti Mobile Ltd. India', '404', 'IN'),
(463, '40407', 'Idea Cellular Ltd. India', '404', 'IN'),
(464, '40409', 'Reliance Telecom Private Ltd. India', '404', 'IN'),
(465, '40410', 'Bharti Cellular Ltd. India', '404', 'IN'),
(466, '40411', 'Sterling Cellular Ltd. India', '404', 'IN'),
(467, '40412', 'Escotel Mobile Communications Pvt Ltd. India', '404', 'IN'),
(468, '40413', 'Hutchinson Essar South Ltd. India', '404', 'IN'),
(469, '40414', 'Spice Communications Ltd. India', '404', 'IN'),
(470, '40415', 'Aircell Digilink India Ltd.', '404', 'IN'),
(471, '40416', 'Hexcom India', '404', 'IN'),
(472, '40418', 'Reliance Telecom Private Ltd. India', '404', 'IN'),
(473, '40419', 'Escotel Mobile Communications Pvt Ltd. India', '404', 'IN'),
(474, '40420', 'Hutchinson Max Telecom India', '404', 'IN'),
(475, '40421', 'BPL Mobile Communications Ltd. India', '404', 'IN'),
(476, '40422', 'Idea Cellular Ltd. India', '404', 'IN'),
(477, '40424', 'Idea Cellular Ltd. India', '404', 'IN'),
(478, '40427', 'BPL Cellular Ltd. India', '404', 'IN'),
(479, '40430', 'Usha Martin Telecom Ltd. India', '404', 'IN'),
(480, '40431', 'Bharti Mobinet Ltd. India', '404', 'IN'),
(481, '40434', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(482, '40436', 'Reliance Telecom Private Ltd. India', '404', 'IN'),
(483, '40438', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(484, '40440', 'Bharti Mobinet Ltd. India', '404', 'IN'),
(485, '40441', 'RPG Cellular India', '404', 'IN'),
(486, '40442', 'Aircel Ltd. India', '404', 'IN'),
(487, '40443', 'BPL Mobile Cellular Ltd. India', '404', 'IN'),
(488, '40444', 'Spice Communications Ltd. India', '404', 'IN'),
(489, '40446', 'BPL Cellular Ltd. India', '404', 'IN'),
(490, '40449', 'Bharti Mobile Ltd. India', '404', 'IN'),
(491, '40450', 'Reliance Telecom Private Ltd. India', '404', 'IN'),
(492, '40451', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(493, '40452', 'Reliance Telecom Private Ltd. India', '404', 'IN'),
(494, '40453', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(495, '40454', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(496, '40455', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(497, '40456', 'Escotel Mobile Communications Pvt Ltd. India', '404', 'IN'),
(498, '40457', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(499, '40458', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(500, '40459', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(501, '40460', 'Aircell Digilink India Ltd.', '404', 'IN'),
(502, '40462', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(503, '40464', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(504, '40466', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(505, '40467', 'Reliance Telecom Private Ltd. India', '404', 'IN'),
(506, '40468', 'Mahanagar Telephone Nigam Ltd. India', '404', 'IN'),
(507, '40469', 'Mahanagar Telephone Nigam Ltd. India', '404', 'IN'),
(508, '40470', 'Hexicom India', '404', 'IN'),
(509, '40471', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(510, '40472', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(511, '40473', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(512, '40474', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(513, '40475', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(514, '40476', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(515, '40477', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(516, '40478', 'BTA Cellcom Ltd. India', '404', 'IN'),
(517, '40480', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(518, '40481', 'Bharat Sanchar Nigam Ltd. (BSNL) India', '404', 'IN'),
(519, '40482', 'Escorts Telecom Ltd. India', '404', 'IN'),
(520, '40483', 'Reliable Internet Services Ltd. India', '404', 'IN'),
(521, '40484', 'Hutchinson Essar South Ltd. India', '404', 'IN'),
(522, '40485', 'Reliance Telecom Private Ltd. India', '404', 'IN'),
(523, '40486', 'Hutchinson Essar South Ltd. India', '404', 'IN'),
(524, '40487', 'Escorts Telecom Ltd. India', '404', 'IN'),
(525, '40488', 'Escorts Telecom Ltd. India', '404', 'IN'),
(526, '40489', 'Escorts Telecom Ltd. India', '404', 'IN'),
(527, '40490', 'Bharti Cellular Ltd. India', '404', 'IN'),
(528, '40492', 'Bharti Cellular Ltd. India', '404', 'IN'),
(529, '40493', 'Bharti Cellular Ltd. India', '404', 'IN'),
(530, '40494', 'Bharti Cellular Ltd. India', '404', 'IN'),
(531, '40495', 'Bharti Cellular Ltd. India', '404', 'IN'),
(532, '40496', 'Bharti Cellular Ltd. India', '404', 'IN'),
(533, '40497', 'Bharti Cellular Ltd. India', '404', 'IN'),
(534, '40498', 'Bharti Cellular Ltd. India', '404', 'IN'),
(535, '41001', 'Mobilink Pakistan', '410', 'PK'),
(536, '41003', 'PAK Telecom Mobile Ltd. (UFONE) Pakistan', '410', 'PK'),
(537, '41201', 'AWCC Afghanistan', '412', 'AF'),
(538, '41220', 'Roshan Afghanistan', '412', 'AF'),
(539, '41230', 'New1 Afghanistan', '412', 'AF'),
(540, '41240', 'Areeba Afghanistan', '412', 'AF'),
(541, '41288', 'Afghan Telecom', '412', 'AF'),
(542, '41302', 'MTN Network Ltd. Sri Lanka', '413', 'LK'),
(543, '41303', 'Celtel Lanka Ltd. Sri Lanka', '413', 'LK'),
(544, '41401', 'Myanmar Post and Telecommunication', '414', 'MM'),
(545, '41532', 'Cellis Lebanon', '415', 'LB'),
(546, '41533', 'Cellis Lebanon', '415', 'LB'),
(547, '41534', 'Cellis Lebanon', '415', 'LB'),
(548, '41535', 'Cellis Lebanon', '415', 'LB'),
(549, '41536', 'Libancell', '415', 'LB'),
(550, '41537', 'Libancell', '415', 'LB'),
(551, '41538', 'Libancell', '415', 'LB'),
(552, '41539', 'Libancell', '415', 'LB'),
(553, '41601', 'Fastlink Jordan', '416', 'JO'),
(554, '41602', 'Xpress Jordan', '416', 'JO'),
(555, '41603', 'Umniah Jordan', '416', 'JO'),
(556, '41677', 'Mobilecom Jordan', '416', 'JO'),
(557, '41701', 'Syriatel', '417', 'SY'),
(558, '41702', 'Spacetel Syria', '417', 'SY'),
(559, '41709', 'Syrian Telecom', '417', 'SY'),
(560, '41902', 'Mobile Telecommunications Company Kuwait', '419', 'KW'),
(561, '41903', 'Wataniya Telecom Kuwait', '419', 'KW'),
(562, '42001', 'Saudi Telecom', '420', 'SA'),
(563, '42101', 'Yemen Mobile Phone Company', '421', 'YE'),
(564, '42102', 'Spacetel Yemen', '421', 'YE'),
(565, '42202', 'Oman Mobile Telecommunications Company (Oman Mobile)', '422', 'OM'),
(566, '42203', 'Oman Qatari Telecommunications Company (Nawras)', '422', 'OM'),
(567, '42204', 'Oman Telecommunications Company (Omantel)', '422', 'OM'),
(568, '42402', 'Etisalat United Arab Emirates', '424', 'AE'),
(569, '42501', 'Partner Communications Co. Ltd. Israel', '425', 'IL'),
(570, '42502', 'Cellcom Israel Ltd.', '425', 'IL'),
(571, '42503', 'Pelephone Communications Ltd. Israel', '425', 'IL'),
(572, '42601', 'BHR Mobile Plus Bahrain', '426', 'BH'),
(573, '42701', 'QATARNET', '427', 'QA'),
(574, '42899', 'Mobicom Mongolia', '428', 'MN'),
(575, '42901', 'Nepal Telecommunications', '429', 'NP'),
(576, '43211', 'Telecommunication Company of Iran (TCI)', '432', 'IR'),
(577, '43214', 'Telecommunication Kish Co. (KIFZO) Iran', '432', 'IR'),
(578, '43219', 'Telecommunication Company of Iran (TCI) Isfahan Celcom', '432', 'IR'),
(579, '43401', 'Buztel Uzbekistan', '434', 'UZ'),
(580, '43402', 'Uzmacom Uzbekistan', '434', 'UZ'),
(581, '43404', 'Daewoo Unitel Uzbekistan', '434', 'UZ'),
(582, '43405', 'Coscom Uzbekistan', '434', 'UZ'),
(583, '43407', 'Uzdunrobita Uzbekistan', '434', 'UZ'),
(584, '43601', 'JC Somoncom Tajikistan', '436', 'TJ'),
(585, '43602', 'CJSC Indigo Tajikistan', '436', 'TJ'),
(586, '43603', 'TT mobile Tajikistan', '436', 'TJ'),
(587, '43604', 'Josa Babilon-T Tajikistan', '436', 'TJ'),
(588, '43605', 'CTJTHSC Tajik-tel', '436', 'TJ'),
(589, '43701', 'Bitel GSM Kyrgyzstan', '437', 'KG'),
(590, '43801', 'Barash Communication Technologies (BCTI) Turkmenistan', '438', 'TM'),
(591, '43802', 'TM-Cell Turkmenistan', '438', 'TM'),
(592, '44001', 'NTT DoCoMo, Inc. Japan', '440', 'JP'),
(593, '44002', 'NTT DoCoMo Kansai, Inc.  Japan', '440', 'JP'),
(594, '44003', 'NTT DoCoMo Hokuriku, Inc. Japan', '440', 'JP'),
(595, '44004', 'Vodafone Japan', '440', 'JP'),
(596, '44006', 'Vodafone Japan', '440', 'JP'),
(597, '44007', 'KDDI Corporation Japan', '440', 'JP'),
(598, '44008', 'KDDI Corporation Japan', '440', 'JP'),
(599, '44009', 'NTT DoCoMo Kansai Inc. Japan', '440', 'JP'),
(600, '44010', 'NTT DoCoMo Kansai Inc. Japan', '440', 'JP'),
(601, '44011', 'NTT DoCoMo Tokai Inc. Japan', '440', 'JP'),
(602, '44012', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(603, '44013', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(604, '44014', 'NTT DoCoMo Tohoku Inc. Japan', '440', 'JP'),
(605, '44015', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(606, '44016', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(607, '44017', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(608, '44018', 'NTT DoCoMo Tokai Inc. Japan', '440', 'JP'),
(609, '44019', 'NTT DoCoMo Hokkaido Japan', '440', 'JP'),
(610, '44020', 'NTT DoCoMo Hokuriku Inc. Japan', '440', 'JP'),
(611, '44021', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(612, '44022', 'NTT DoCoMo Kansai Inc. Japan', '440', 'JP'),
(613, '44023', 'NTT DoCoMo Tokai Inc. Japan', '440', 'JP'),
(614, '44024', 'NTT DoCoMo Chugoku Inc. Japan', '440', 'JP'),
(615, '44025', 'NTT DoCoMo Hokkaido Inc. Japan', '440', 'JP'),
(616, '44026', 'NTT DoCoMo Kyushu Inc. Japan', '440', 'JP'),
(617, '44027', 'NTT DoCoMo Tohoku Inc. Japan', '440', 'JP'),
(618, '44028', 'NTT DoCoMo Shikoku Inc. Japan', '440', 'JP'),
(619, '44029', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(620, '44030', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(621, '44031', 'NTT DoCoMo Kansai Inc. Japan', '440', 'JP'),
(622, '44032', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(623, '44033', 'NTT DoCoMo Tokai Inc. Japan', '440', 'JP'),
(624, '44034', 'NTT DoCoMo Kyushu Inc. Japan', '440', 'JP'),
(625, '44035', 'NTT DoCoMo Kansai Inc. Japan', '440', 'JP'),
(626, '44036', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(627, '44037', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(628, '44038', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(629, '44039', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(630, '44040', 'Vodafone Japan', '440', 'JP'),
(631, '44041', 'Vodafone Japan', '440', 'JP'),
(632, '44042', 'Vodafone Japan', '440', 'JP'),
(633, '44043', 'Vodafone Japan', '440', 'JP'),
(634, '44044', 'Vodafone Japan', '440', 'JP'),
(635, '44045', 'Vodafone Japan', '440', 'JP'),
(636, '44046', 'Vodafone Japan', '440', 'JP'),
(637, '44047', 'Vodafone Japan', '440', 'JP'),
(638, '44048', 'Vodafone Japan', '440', 'JP'),
(639, '44049', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(640, '44050', 'KDDI Corporation Japan', '440', 'JP'),
(641, '44051', 'KDDI Corporation Japan', '440', 'JP'),
(642, '44052', 'KDDI Corporation Japan', '440', 'JP'),
(643, '44053', 'KDDI Corporation Japan', '440', 'JP'),
(644, '44054', 'KDDI Corporation Japan', '440', 'JP'),
(645, '44055', 'KDDI Corporation Japan', '440', 'JP'),
(646, '44056', 'KDDI Corporation Japan', '440', 'JP'),
(647, '44058', 'NTT DoCoMo Kansai Inc. Japan', '440', 'JP'),
(648, '44060', 'NTT DoCoMo Kansai Inc. Japan', '440', 'JP'),
(649, '44061', 'NTT DoCoMo Chugoku Inc. Japan', '440', 'JP'),
(650, '44062', 'NTT DoCoMo Kyushu Inc. Japan', '440', 'JP'),
(651, '44063', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(652, '44064', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(653, '44065', 'NTT DoCoMo Shikoku Inc. Japan', '440', 'JP'),
(654, '44066', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(655, '44067', 'NTT DoCoMo Tohoku Inc. Japan', '440', 'JP'),
(656, '44068', 'NTT DoCoMo Kyushu Inc. Japan', '440', 'JP'),
(657, '44069', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(658, '44070', 'KDDI Corporation Japan', '440', 'JP'),
(659, '44071', 'KDDI Corporation Japan', '440', 'JP'),
(660, '44072', 'KDDI Corporation Japan', '440', 'JP'),
(661, '44073', 'KDDI Corporation Japan', '440', 'JP'),
(662, '44074', 'KDDI Corporation Japan', '440', 'JP'),
(663, '44075', 'KDDI Corporation Japan', '440', 'JP'),
(664, '44076', 'KDDI Corporation Japan', '440', 'JP'),
(665, '44077', 'KDDI Corporation Japan', '440', 'JP'),
(666, '44078', 'Okinawa Cellular Telephone Japan', '440', 'JP'),
(667, '44079', 'KDDI Corporation Japan', '440', 'JP'),
(668, '44080', 'TU-KA Cellular Tokyo Inc. Japan', '440', 'JP'),
(669, '44081', 'TU-KA Cellular Tokyo Inc. Japan', '440', 'JP'),
(670, '44082', 'TU-KA Phone Kansai Inc. Japan', '440', 'JP'),
(671, '44083', 'TU-KA Cellular Tokai Inc. Japan', '440', 'JP'),
(672, '44084', 'TU-KA Phone Kansai Inc. Japan', '440', 'JP'),
(673, '44085', 'TU-KA Cellular Tokai Inc. Japan', '440', 'JP'),
(674, '44086', 'TU-KA Cellular Tokyo Inc. Japan', '440', 'JP'),
(675, '44087', 'NTT DoCoMo Chugoku Inc. Japan', '440', 'JP'),
(676, '44088', 'KDDI Corporation Japan', '440', 'JP'),
(677, '44089', 'KDDI Corporation Japan', '440', 'JP'),
(678, '44090', 'Vodafone Japan', '440', 'JP'),
(679, '44092', 'Vodafone Japan', '440', 'JP'),
(680, '44093', 'Vodafone Japan', '440', 'JP'),
(681, '44094', 'Vodafone Japan', '440', 'JP'),
(682, '44095', 'Vodafone Japan', '440', 'JP'),
(683, '44096', 'Vodafone Japan', '440', 'JP'),
(684, '44097', 'Vodafone Japan', '440', 'JP'),
(685, '44098', 'Vodafone Japan', '440', 'JP'),
(686, '44099', 'NTT DoCoMo Inc. Japan', '440', 'JP'),
(687, '44140', 'NTT DoCoMo Inc. Japan', '441', 'JP'),
(688, '44141', 'NTT DoCoMo Inc. Japan', '441', 'JP'),
(689, '44142', 'NTT DoCoMo Inc. Japan', '441', 'JP'),
(690, '44143', 'NTT DoCoMo Kansai Inc. Japan', '441', 'JP'),
(691, '44144', 'NTT DoCoMo Chugoku Inc. Japan', '441', 'JP'),
(692, '44145', 'NTT DoCoMo Shikoku Inc. Japan', '441', 'JP'),
(693, '44150', 'TU-KA Cellular Tokyo Inc. Japan', '441', 'JP'),
(694, '44151', 'TU-KA Phone Kansai Inc. Japan', '441', 'JP'),
(695, '44161', 'Vodafone Japan', '441', 'JP'),
(696, '44162', 'Vodafone Japan', '441', 'JP'),
(697, '44163', 'Vodafone Japan', '441', 'JP'),
(698, '44164', 'Vodafone Japan', '441', 'JP'),
(699, '44165', 'Vodafone Japan', '441', 'JP'),
(700, '44170', 'KDDI Corporation Japan', '441', 'JP'),
(701, '44190', 'NTT DoCoMo Inc. Japan', '441', 'JP'),
(702, '44191', 'NTT DoCoMo Inc. Japan', '441', 'JP'),
(703, '44192', 'NTT DoCoMo Inc. Japan', '441', 'JP'),
(704, '44193', 'NTT DoCoMo Hokkaido Inc. Japan', '441', 'JP'),
(705, '44194', 'NTT DoCoMo Tohoku Inc. Japan', '441', 'JP'),
(706, '44198', 'NTT DoCoMo Kyushu Inc. Japan', '441', 'JP'),
(707, '44199', 'NTT DoCoMo Kyushu Inc. Japan', '441', 'JP'),
(708, '45201', 'Mobifone Vietnam', '452', 'VN'),
(709, '45202', 'Vinaphone Vietnam', '452', 'VN'),
(710, '45400', 'CSL', '454', 'HK'),
(711, '45401', 'MVNO/CITIC Hong Kong', '454', 'HK'),
(712, '45402', '3G Radio System/HKCSL3G Hong Kong', '454', 'HK'),
(713, '45403', 'Hutchison 3G', '454', 'HK'),
(714, '45404', 'GSM900/GSM1800/Hutchison Hong Kong', '454', 'HK'),
(715, '45405', 'CDMA/Hutchison Hong Kong', '454', 'HK'),
(716, '45406', 'SMC', '454', 'HK'),
(717, '45407', 'MVNO/China Unicom International Ltd. Hong Kong', '454', 'HK'),
(718, '45408', 'MVNO/Trident Hong Kong', '454', 'HK'),
(719, '45409', 'MVNO/China Motion Telecom (HK) Ltd. Hong Kong', '454', 'HK'),
(720, '45410', 'GSM1800New World PCS Ltd. Hong Kong', '454', 'HK'),
(721, '45411', 'MVNO/CHKTL Hong Kong', '454', 'HK'),
(722, '45412', 'PEOPLES', '454', 'HK'),
(723, '45415', '3G Radio System/SMT3G Hong Kong', '454', 'HK'),
(724, '45416', 'GSM1800/Mandarin Communications Ltd. Hong Kong', '454', 'HK'),
(725, '45418', 'GSM7800/Hong Kong CSL Ltd.', '454', 'HK'),
(726, '45419', 'Sunday3G', '454', 'HK'),
(727, '45500', 'Smartone Mobile Communications (Macao) Ltd.', '455', 'MO'),
(728, '45501', 'CTM GSM Macao', '455', 'MO'),
(729, '45503', 'Hutchison Telecom Macao', '455', 'MO'),
(730, '45601', 'Mobitel (Cam GSM) Cambodia', '456', 'KH'),
(731, '45602', 'Samart (Casacom) Cambodia', '456', 'KH'),
(732, '45603', 'S Telecom (CDMA) (reserved) Cambodia', '456', 'KH'),
(733, '45618', 'Camshin (Shinawatra) Cambodia', '456', 'KH'),
(734, '45701', 'Lao Telecommunications', '457', 'LA'),
(735, '45702', 'ETL Mobile Lao', '457', 'LA'),
(736, '45708', 'Millicom Lao', '457', 'LA'),
(737, '46000', 'China Mobile', '460', 'CN'),
(738, '46001', 'China Unicom', '460', 'CN'),
(739, '46002', 'China Mobile', '460', 'CN'),
(740, '46003', 'China Telecom', '460', 'CN'),
(741, '46004', 'China Satellite Global Star Network', '460', 'CN'),
(742, '46601', 'Far EasTone', '466', 'TW'),
(743, '46606', 'TUNTEX', '466', 'TW'),
(744, '46668', 'ACeS', '466', 'TW'),
(745, '46688', 'KGT', '466', 'TW'),
(746, '46689', 'KGT', '466', 'TW'),
(747, '46692', 'Chunghwa', '466', 'TW'),
(748, '46693', 'MobiTai', '466', 'TW'),
(749, '46697', 'TWN GSM', '466', 'TW'),
(750, '46699', 'TransAsia', '466', 'TW'),
(751, '47001', 'GramenPhone Bangladesh', '470', 'BD'),
(752, '47002', 'Aktel Bangladesh', '470', 'BD'),
(753, '47003', 'Mobile 2000 Bangladesh', '470', 'BD'),
(754, '47201', 'DhiMobile Maldives', '472', 'MV'),
(755, '50200', 'Art900 Malaysia', '502', 'MY'),
(756, '50212', 'Maxis Malaysia', '502', 'MY'),
(757, '50213', 'TM Touch Malaysia', '502', 'MY'),
(758, '50216', 'DiGi', '502', 'MY'),
(759, '50217', 'TimeCel Malaysia', '502', 'MY'),
(760, '50219', 'CelCom Malaysia', '502', 'MY'),
(761, '50501', 'Telstra Corporation Ltd. Australia', '505', 'AU'),
(762, '50502', 'Optus Mobile Pty. Ltd. Australia', '505', 'AU'),
(763, '50503', 'Vodafone Network Pty. Ltd. Australia', '505', 'AU'),
(764, '50504', 'Department of Defence Australia', '505', 'AU'),
(765, '50505', 'The Ozitel Network Pty. Ltd. Australia', '505', 'AU'),
(766, '50506', 'Hutchison 3G Australia Pty. Ltd.', '505', 'AU'),
(767, '50507', 'Vodafone Network Pty. Ltd. Australia', '505', 'AU'),
(768, '50508', 'One.Tel GSM 1800 Pty. Ltd. Australia', '505', 'AU'),
(769, '50509', 'Airnet Commercial Australia Ltd.', '505', 'AU'),
(770, '50511', 'Telstra Corporation Ltd. Australia', '505', 'AU'),
(771, '50512', 'Hutchison Telecommunications (Australia) Pty. Ltd.', '505', 'AU'),
(772, '50514', 'AAPT Ltd. Australia', '505', 'AU'),
(773, '50515', '3GIS Pty Ltd. (Telstra & Hutchison 3G) Australia', '505', 'AU'),
(774, '50524', 'Advanced Communications Technologies Pty. Ltd. Australia', '505', 'AU'),
(775, '50571', 'Telstra Corporation Ltd. Australia', '505', 'AU'),
(776, '50572', 'Telstra Corporation Ltd. Australia', '505', 'AU'),
(777, '50588', 'Localstar Holding Pty. Ltd. Australia', '505', 'AU'),
(778, '50590', 'Optus Ltd. Australia', '505', 'AU'),
(779, '50599', 'One.Tel GSM 1800 Pty. Ltd. Australia', '505', 'AU'),
(780, '51000', 'PSN Indonesia', '510', 'ID'),
(781, '51001', 'Satelindo Indonesia', '510', 'ID'),
(782, '51008', 'Natrindo (Lippo Telecom) Indonesia', '510', 'ID'),
(783, '51010', 'Telkomsel Indonesia', '510', 'ID'),
(784, '51011', 'Excelcomindo Indonesia', '510', 'ID'),
(785, '51021', 'Indosat - M3 Indonesia', '510', 'ID'),
(786, '51028', 'Komselindo Indonesia', '510', 'ID'),
(787, '51501', 'Islacom Philippines', '515', 'PH'),
(788, '51502', 'Globe Telecom Philippines', '515', 'PH'),
(789, '51503', 'Smart Communications Philippines', '515', 'PH'),
(790, '51505', 'Digitel Philippines', '515', 'PH'),
(791, '52000', 'CAT CDMA Thailand', '520', 'TH'),
(792, '52001', 'AIS GSM Thailand', '520', 'TH'),
(793, '52015', 'ACT Mobile Thailand', '520', 'TH'),
(794, '52501', 'SingTel ST GSM900 Singapore', '525', 'SG'),
(795, '52502', 'SingTel ST GSM1800 Singapore', '525', 'SG'),
(796, '52503', 'MobileOne Singapore', '525', 'SG'),
(797, '52505', 'STARHUB-SGP', '525', 'SG'),
(798, '52512', 'Digital Trunked Radio Network Singapore', '525', 'SG'),
(799, '52811', 'DST Com Brunei ', '528', 'BN'),
(800, '53000', 'Reserved for AMPS MIN based IMSIs New Zealand', '530', 'NZ'),
(801, '53001', 'Vodafone New Zealand GSM Mobile Network', '530', 'NZ'),
(802, '53002', 'Teleom New Zealand CDMA Mobile Network', '530', 'NZ'),
(803, '53003', 'Walker Wireless Ltd. New Zealand', '530', 'NZ'),
(804, '53028', 'Econet Wireless New Zealand GSM Mobile Network', '530', 'NZ'),
(805, '53701', 'Pacific Mobile Communications Papua New Guinea', '537', 'PG'),
(806, '53702', 'Dawamiba PNG Ltd Papua New Guinea', '537', 'PG'),
(807, '53703', 'Digicel Ltd Papua New Guinea', '537', 'PG'),
(808, '53901', 'Tonga Communications Corporation', '539', 'TO'),
(809, '53943', 'Shoreline Communication Tonga', '539', 'TO'),
(810, '54101', 'SMILE Vanuatu', '541', 'VU'),
(811, '54201', 'Vodafone Fiji', '542', 'FJ'),
(812, '54411', 'Blue Sky', '544', 'AS'),
(813, '54601', 'OPT Mobilis New Caledonia', '546', 'NC'),
(814, '54720', 'Tikiphone French Polynesia', '547', 'PF'),
(815, '54801', 'Telecom Cook', '548', 'CK'),
(816, '54901', 'Telecom Samoa Cellular Ltd.', '549', 'WS'),
(817, '54927', 'GoMobile SamoaTel Ltd', '549', 'WS'),
(818, '55001', 'FSM Telecom Micronesia', '550', 'FM'),
(819, '55201', 'Palau National Communications Corp. (a.k.a. PNCC)', '552', 'PW'),
(820, '60201', 'EMS - Mobinil Egypt', '602', 'EG'),
(821, '60202', 'Vodafone Egypt', '602', 'EG'),
(822, '60301', 'Algrie Telecom', '603', 'DZ'),
(823, '60302', 'Orascom Telecom Algrie', '603', 'DZ'),
(824, '60400', 'Meditelecom (GSM) Morocco', '604', 'MA'),
(825, '60401', 'Ittissalat Al Maghrid Morocco', '604', 'MA'),
(826, '60502', 'Tunisie Telecom', '605', 'TN'),
(827, '60503', 'Orascom Telecom Tunisia', '605', 'TN'),
(828, '60701', 'Gamcel Gambia', '607', 'GM'),
(829, '60702', 'Africell Gambia', '607', 'GM'),
(830, '60703', 'Comium Services Ltd Gambia', '607', 'GM'),
(831, '60801', 'Sonatel Senegal', '608', 'SN'),
(832, '60802', 'Sentel GSM Senegal', '608', 'SN'),
(833, '60901', 'Mattel S.A.', '609', 'MR'),
(834, '60902', 'Chinguitel S.A. ', '609', 'MR'),
(835, '60910', 'Mauritel Mobiles  ', '609', 'MR'),
(836, '61001', 'Malitel', '610', 'ML'),
(837, '61101', 'Spacetel Guinea', '611', 'GN'),
(838, '61102', 'Sotelgui Guinea', '611', 'GN'),
(839, '61202', 'Atlantique Cellulaire Cote d Ivoire', '612', 'CI'),
(840, '61203', 'Orange Cote dIvoire', '612', 'CI'),
(841, '61204', 'Comium Cote d Ivoire', '612', 'CI'),
(842, '61205', 'Loteny Telecom Cote d Ivoire', '612', 'CI'),
(843, '61206', 'Oricel Cote d Ivoire', '612', 'CI'),
(844, '61207', 'Aircomm Cote d Ivoire', '612', 'CI'),
(845, '61302', 'Celtel Burkina Faso', '613', 'BF'),
(846, '61303', 'Telecel Burkina Faso', '613', 'BF'),
(847, '61401', 'Sahel.Com Niger', '614', 'NE'),
(848, '61402', 'Celtel Niger', '614', 'NE'),
(849, '61403', 'Telecel Niger', '614', 'NE'),
(850, '61501', 'Togo Telecom', '615', 'TG'),
(851, '61601', 'Libercom Benin', '616', 'BJ'),
(852, '61602', 'Telecel Benin', '616', 'BJ'),
(853, '61603', 'Spacetel Benin', '616', 'BJ'),
(854, '61701', 'Cellplus Mauritius', '617', 'MU'),
(855, '61702', 'Mahanagar Telephone (Mauritius) Ltd.', '617', 'MU'),
(856, '61710', 'Emtel Mauritius', '617', 'MU'),
(857, '61804', 'Comium Liberia', '618', 'LR'),
(858, '61901', 'Celtel Sierra Leone', '619', 'SL'),
(859, '61902', 'Millicom Sierra Leone', '619', 'SL'),
(860, '61903', 'Africell Sierra Leone', '619', 'SL'),
(861, '61904', 'Comium (Sierra Leone) Ltd.', '619', 'SL'),
(862, '61905', 'Lintel (Sierra Leone) Ltd.', '619', 'SL'),
(863, '61925', 'Mobitel Sierra Leone', '619', 'SL'),
(864, '61940', 'Datatel (SL) Ltd GSM Sierra Leone', '619', 'SL'),
(865, '61950', 'Dtatel (SL) Ltd CDMA Sierra Leone', '619', 'SL'),
(866, '62001', 'Spacefon Ghana', '620', 'GH'),
(867, '62002', 'Ghana Telecom Mobile', '620', 'GH'),
(868, '62003', 'Mobitel Ghana', '620', 'GH'),
(869, '62004', 'Kasapa Telecom Ltd. Ghana', '620', 'GH'),
(870, '62120', 'Econet Wireless Nigeria Ltd.', '621', 'NG'),
(871, '62130', 'MTN Nigeria Communications', '621', 'NG'),
(872, '62140', 'Nigeria Telecommunications Ltd.', '621', 'NG'),
(873, '62201', 'Celtel Chad', '622', 'TD'),
(874, '62202', 'Tchad Mobile', '622', 'TD'),
(875, '62301', 'Centrafrique Telecom Plus (CTP)', '623', 'CF'),
(876, '62302', 'Telecel Centrafrique (TC)', '623', 'CF'),
(877, '62303', 'Celca (Socatel) Central African Rep.', '623', 'CF'),
(878, '62401', 'Mobile Telephone Networks Cameroon', '624', 'CM'),
(879, '62402', 'Orange Cameroun', '624', 'CM'),
(880, '62501', 'Cabo Verde Telecom', '625', 'CV'),
(881, '62601', 'Companhia Santomese de Telecomunicacoes', '626', 'ST'),
(882, '62701', 'Guinea Ecuatorial de Telecomunicaciones Sociedad Anonima', '627', 'GQ'),
(883, '62801', 'Libertis S.A. Gabon', '628', 'GA'),
(884, '62802', 'Telecel Gabon S.A.', '628', 'GA'),
(885, '62803', 'Celtel Gabon S.A.', '628', 'GA'),
(886, '62901', 'Celtel Congo', '629', 'CG'),
(887, '62910', 'Libertis Telecom Congo', '629', 'CG'),
(888, '63001', 'Vodacom Congo RDC sprl', '630', 'CD'),
(889, '63005', 'Supercell Sprl Congo', '630', 'CD'),
(890, '63086', 'Congo-Chine Telecom s.a.r.l.', '630', 'CD'),
(891, '63102', 'Unitel Angola', '631', 'AO'),
(892, '63201', 'Guinetel S.A. Guinea-Bissau', '632', 'GW'),
(893, '63202', 'Spacetel Guine-Bissau S.A.', '632', 'GW'),
(894, '63301', 'Cable & Wireless (Seychelles) Ltd.', '633', 'SC'),
(895, '63302', 'Mediatech International Ltd. Seychelles', '633', 'SC'),
(896, '63310', 'Telecom (Seychelles) Ltd.', '633', 'SC'),
(897, '63401', 'SD Mobitel Sudan', '634', 'MZ'),
(898, '63402', 'Areeba-Sudan', '634', 'MZ'),
(899, '63510', 'MTN Rwandacell', '635', 'RW'),
(900, '63601', 'ETH MTN Ethiopia', '636', 'ET'),
(901, '63730', 'Golis Telecommunications Company Somalia', '637', 'SO'),
(902, '63801', 'Evatis Djibouti', '638', 'DJ'),
(903, '63902', 'Safaricom Ltd. Kenya', '639', 'KE'),
(904, '63903', 'Kencell Communications Ltd. Kenya', '639', 'KE'),
(905, '64002', 'MIC (T) Ltd. Tanzania', '640', 'TZ'),
(906, '64003', 'Zantel Tanzania', '640', 'TZ'),
(907, '64004', 'Vodacom (T) Ltd. Tanzania', '640', 'TZ'),
(908, '64005', 'Celtel (T) Ltd. Tanzania', '640', 'TZ');
INSERT INTO `razor_dim_devicesupplier` (`devicesupplier_sk`, `mccmnc`, `devicesupplier_name`, `countrycode`, `countryname`) VALUES
(909, '64101', 'Celtel Uganda', '641', 'UG'),
(910, '64110', 'MTN Uganda Ltd.', '641', 'UG'),
(911, '64111', 'Uganda Telecom Ltd.', '641', 'UG'),
(912, '64201', 'Spacetel Burundi', '642', 'BI'),
(913, '64202', 'Safaris Burundi', '642', 'BI'),
(914, '64203', 'Telecel Burundi Company', '642', 'BI'),
(915, '64301', 'T.D.M. GSM Mozambique', '643', 'MZ'),
(916, '64304', 'VM Sarl Mozambique', '643', 'MZ'),
(917, '64501', 'Celtel Zambia Ltd.', '645', 'ZM'),
(918, '64502', 'Telecel Zambia Ltd.', '645', 'ZM'),
(919, '64503', 'Zamtel Zambia', '645', 'ZM'),
(920, '64601', 'MADACOM Madagascar', '646', 'MG'),
(921, '64602', 'Orange Madagascar', '646', 'MG'),
(922, '64604', 'Telecom Malagasy Mobile Madagascar', '646', 'MG'),
(923, '64700', 'Orange La Reunion', '647', 'RE'),
(924, '64702', 'Outremer Telecom', '647', 'RE'),
(925, '64710', 'Societe Reunionnaise du Radiotelephone', '647', 'RE'),
(926, '64801', 'Net One Zimbabwe', '648', 'ZW'),
(927, '64803', 'Telecel Zimbabwe', '648', 'ZW'),
(928, '64804', 'Econet Zimbabwe', '648', 'ZW'),
(929, '64901', 'Mobile Telecommunications Ltd. Namibia', '649', 'NA'),
(930, '64903', 'Powercom Pty Ltd Namibia', '649', 'NA'),
(931, '65001', 'Telekom Network Ltd. Malawi', '650', 'MW'),
(932, '65010', 'Celtel ltd. Malawi', '650', 'MW'),
(933, '65101', 'Vodacom Lesotho (pty) Ltd.', '651', 'LS'),
(934, '65102', 'Econet Ezin-cel Lesotho', '651', 'LS'),
(935, '65201', 'Mascom Wireless (Pty) Ltd. Botswana', '652', 'BW'),
(936, '65202', 'Orange Botswana (Pty) Ltd.', '652', 'BW'),
(937, '65310', 'Swazi MTN', '653', 'SZ'),
(938, '65401', 'HURI - SNPT Comoros', '654', 'KM'),
(939, '65501', 'Vodacom (Pty) Ltd. South Africa', '655', 'ZA'),
(940, '65506', 'Sentech (Pty) Ltd. South Africa', '655', 'ZA'),
(941, '65507', 'Cell C (Pty) Ltd. South Africa', '655', 'ZA'),
(942, '65510', 'Mobile Telephone Networks South Africa', '655', 'ZA'),
(943, '65511', 'SAPS Gauteng South Africa', '655', 'ZA'),
(944, '65521', 'Cape Town Metropolitan Council South Africa', '655', 'ZA'),
(945, '65530', 'Bokamoso Consortium South Africa', '655', 'ZA'),
(946, '65531', 'Karabo Telecoms (Pty) Ltd. South Africa', '655', 'ZA'),
(947, '65532', 'Ilizwi Telecommunications South Africa', '655', 'ZA'),
(948, '65533', 'Thinta Thinta Telecommunications South Africa', '655', 'ZA'),
(949, '65534', 'Bokone Telecoms South Africa', '655', 'ZA'),
(950, '65535', 'Kingdom Communications South Africa', '655', 'ZA'),
(951, '65536', 'Amatole Telecommunication Services South Africa', '655', 'ZA'),
(952, '70267', 'Belize Telecommunications Ltd., GSM 1900', '702', 'BZ'),
(953, '70268', 'International Telecommunications Ltd. (INTELCO) Belize', '702', 'BZ'),
(954, '70401', 'Servicios de Comunicaciones Personales Inalambricas, S.A. Guatemala', '704', 'GT'),
(955, '70402', 'Comunicaciones Celulares S.A. Guatemala', '704', 'GT'),
(956, '70403', 'Telefonica Centroamerica Guatemala S.A.', '704', 'GT'),
(957, '70601', 'CTE Telecom Personal, S.A. de C.V. El Salvador', '706', 'SV'),
(958, '70602', 'Digicel, S.A. de C.V. El Salvador', '706', 'SV'),
(959, '70603', 'Telemovil El Salvador, S.A.', '706', 'SV'),
(960, '708001', 'Megatel Honduras', '708', 'HN'),
(961, '708002', 'Celtel Honduras', '708', 'HN'),
(962, '708040', 'Digicel Honduras', '708', 'HN'),
(963, '71021', 'Empresa Nicaraguense de Telecomunicaciones, S.A. (ENITEL)', '710', 'NI'),
(964, '71073', 'Servicios de Comunicaciones, S.A. (SERCOM) Nicaragua', '710', 'NI'),
(965, '71201', 'Instituto Costarricense de Electricidad - ICE', '712', 'CR'),
(966, '71401', 'Cable & Wireless Panama S.A.', '714', 'PA'),
(967, '71402', 'BSC de Panama S.A.', '714', 'PA'),
(968, '71610', 'TIM Peru', '716', 'PE'),
(969, '722010', 'Compaia de Radiocomunicaciones Moviles S.A. Argentina', '722', 'AR'),
(970, '722020', 'Nextel Argentina srl', '722', 'AR'),
(971, '722070', 'Telefonica Comunicaciones Personales S.A. Argentina', '722', 'AR'),
(972, '722310', 'CTI PCS S.A. Argentina', '722', 'AR'),
(973, '722320', 'Compaia de Telefonos del Interior Norte S.A. Argentina', '722', 'AR'),
(974, '722330', 'Compaia de Telefonos del Interior S.A. Argentina', '722', 'AR'),
(975, '722341', 'Telecom Personal S.A. Argentina', '722', 'AR'),
(976, '72400', 'Telet Brazil', '724', 'BR'),
(977, '72401', 'CRT Cellular Brazil', '724', 'BR'),
(978, '72402', 'Global Telecom Brazil', '724', 'BR'),
(979, '72403', 'CTMR Cel Brazil', '724', 'BR'),
(980, '72404', 'BCP Brazil', '724', 'BR'),
(981, '72405', 'Telesc Cel Brazil', '724', 'BR'),
(982, '72406', 'Tess Brazil', '724', 'BR'),
(983, '72407', 'Sercontel Cel Brazil', '724', 'BR'),
(984, '72408', 'Maxitel MG Brazil', '724', 'BR'),
(985, '72409', 'Telepar Cel Brazil', '724', 'BR'),
(986, '72410', 'ATL Algar Brazil', '724', 'BR'),
(987, '72411', 'Telems Cel Brazil', '724', 'BR'),
(988, '72412', 'Americel Brazil', '724', 'BR'),
(989, '72413', 'Telesp Cel Brazil', '724', 'BR'),
(990, '72414', 'Maxitel BA Brazil', '724', 'BR'),
(991, '72415', 'CTBC Cel Brazil', '724', 'BR'),
(992, '72416', 'BSE Brazil', '724', 'BR'),
(993, '72417', 'Ceterp Cel Brazil', '724', 'BR'),
(994, '72418', 'Norte Brasil Tel', '724', 'BR'),
(995, '72419', 'Telemig Cel Brazil', '724', 'BR'),
(996, '72421', 'Telerj Cel Brazil', '724', 'BR'),
(997, '72423', 'Telest Cel Brazil', '724', 'BR'),
(998, '72425', 'Telebrasilia Cel', '724', 'BR'),
(999, '72427', 'Telegoias Cel Brazil', '724', 'BR'),
(1000, '72429', 'Telemat Cel Brazil', '724', 'BR'),
(1001, '72431', 'Teleacre Cel Brazil', '724', 'BR'),
(1002, '72433', 'Teleron Cel Brazil', '724', 'BR'),
(1003, '72435', 'Telebahia Cel Brazil', '724', 'BR'),
(1004, '72437', 'Telergipe Cel Brazil', '724', 'BR'),
(1005, '72439', 'Telasa Cel Brazil', '724', 'BR'),
(1006, '72441', 'Telpe Cel Brazil', '724', 'BR'),
(1007, '72443', 'Telepisa Cel Brazil', '724', 'BR'),
(1008, '72445', 'Telpa Cel Brazil', '724', 'BR'),
(1009, '72447', 'Telern Cel Brazil', '724', 'BR'),
(1010, '72448', 'Teleceara Cel Brazil', '724', 'BR'),
(1011, '72451', 'Telma Cel Brazil', '724', 'BR'),
(1012, '72453', 'Telepara Cel Brazil', '724', 'BR'),
(1013, '72455', 'Teleamazon Cel Brazil', '724', 'BR'),
(1014, '72457', 'Teleamapa Cel Brazil', '724', 'BR'),
(1015, '72459', 'Telaima Cel Brazil', '724', 'BR'),
(1016, '73001', 'Entel Telefonica Movil Chile', '730', 'CL'),
(1017, '73002', 'Telefonica Movil Chile', '730', 'CL'),
(1018, '73003', 'Smartcom Chile', '730', 'CL'),
(1019, '73004', 'Centennial Cayman Corp. Chile S.A.', '730', 'CL'),
(1020, '73005', 'Multikom S.A. Chile', '730', 'CL'),
(1021, '73010', 'Entel Chile', '730', 'CL'),
(1022, '732001', 'Colombia Telecomunicaciones S.A. - Telecom', '732', 'CO'),
(1023, '732002', 'Edatel S.A. Colombia', '732', 'CO'),
(1024, '732101', 'Comcel S.A. Occel S.A./Celcaribe Colombia', '732', 'CO'),
(1025, '732102', 'Bellsouth Colombia S.A.', '732', 'CO'),
(1026, '732103', 'Colombia Movil S.A.', '732', 'CO'),
(1027, '732111', 'Colombia Movil S.A.', '732', 'CO'),
(1028, '732123', 'Telfonica Moviles Colombia S.A.', '732', 'CO'),
(1029, '73401', 'Infonet Venezuela', '734', 'VE'),
(1030, '73402', 'Corporacion Digitel Venezuela', '734', 'VE'),
(1031, '73403', 'Digicel Venezuela', '734', 'VE'),
(1032, '73404', 'Telcel, C.A. Venezuela', '734', 'VE'),
(1033, '73601', 'Nuevatel S.A. Bolivia', '736', 'BO'),
(1034, '73602', 'ENTEL S.A. Bolivia', '736', 'BO'),
(1035, '73603', 'Telecel S.A. Bolivia', '736', 'BO'),
(1036, '73801', 'Cel*Star (Guyana) Inc.', '738', 'GY'),
(1037, '74000', 'Otecel S.A. - Bellsouth Ecuador', '740', 'EC'),
(1038, '74001', 'Porta GSM Ecuador', '740', 'EC'),
(1039, '74002', 'Telecsa S.A. Ecuador', '740', 'EC'),
(1040, '74401', 'Hola Paraguay S.A.', '744', 'PY'),
(1041, '74402', 'Hutchison Telecom S.A. Paraguay', '744', 'PY'),
(1042, '74403', 'Compania Privada de Comunicaciones S.A. Paraguay', '744', 'PY'),
(1043, '74602', 'Telesur Suriname', '746', 'SR'),
(1044, '74800', 'Ancel TDMA Uruguay', '748', 'UY'),
(1045, '74801', 'Ancel GSM Uruguay', '748', 'UY'),
(1046, '74803', 'Ancel Uruguay', '748', 'UY'),
(1047, '74807', 'Movistar Uruguay', '748', 'UY'),
(1048, '74810', 'CTI Movil Uruguay', '748', 'UY'),
(1049, '90101', 'ICO Global Communications', '901', 'International Mobile, shared code'),
(1050, '90102', 'Sense Communications International AS', '901', 'International Mobile, shared code'),
(1051, '90103', 'Iridium Satellite, LLC (GMSS)', '901', 'International Mobile, shared code'),
(1052, '90104', 'Globalstar International Mobile', '901', 'International Mobile, shared code'),
(1053, '90105', 'Thuraya RMSS Network', '901', 'International Mobile, shared code'),
(1054, '90106', 'Thuraya Satellite Telecommunications Company', '901', 'International Mobile, shared code'),
(1055, '90107', 'Ellipso International Mobile', '901', 'International Mobile, shared code'),
(1056, '90108', 'GSM International Mobile', '901', 'International Mobile, shared code'),
(1057, '90109', 'Tele1 Europe', '901', 'International Mobile, shared code'),
(1058, '90110', 'Asia Cellular Satellite (AceS)', '901', 'International Mobile, shared code'),
(1059, '90111', 'Inmarsat Ltd.', '901', 'International Mobile, shared code'),
(1060, '90112', 'Maritime Communications Partner AS (MCP network)', '901', 'International Mobile, shared code'),
(1061, '90113', 'Global Networks, Inc.', '901', 'International Mobile, shared code'),
(1062, '90114', 'Telenor GSM - services in aircraft', '901', 'International Mobile, shared code'),
(1063, '90115', 'SITA GSM services in aircraft', '901', 'International Mobile, shared code'),
(1064, '90116', 'Jasper Systems, Inc.', '901', 'International Mobile, shared code'),
(1065, '90117', 'Jersey Telecom', '901', 'International Mobile, shared code'),
(1066, '90118', 'Cingular Wireless', '901', 'International Mobile, shared code'),
(1067, '90119', 'Vodaphone Malta', '901', 'International Mobile, shared code');

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_errortitle`
--

CREATE TABLE IF NOT EXISTS `razor_dim_errortitle` (
  `title_sk` int(11) NOT NULL,
  `title_name` text NOT NULL,
  `isfix` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_event`
--

CREATE TABLE IF NOT EXISTS `razor_dim_event` (
  `event_sk` int(11) NOT NULL,
  `eventidentifier` varchar(50) NOT NULL,
  `eventname` varchar(50) NOT NULL,
  `active` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `createtime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `event_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_location`
--

CREATE TABLE IF NOT EXISTS `razor_dim_location` (
  `location_sk` int(11) NOT NULL,
  `country` varchar(60) NOT NULL,
  `region` varchar(60) NOT NULL,
  `city` varchar(60) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_network`
--

CREATE TABLE IF NOT EXISTS `razor_dim_network` (
  `network_sk` int(11) NOT NULL,
  `networkname` varchar(256) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_product`
--

CREATE TABLE IF NOT EXISTS `razor_dim_product` (
  `product_sk` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `product_name` varchar(256) NOT NULL,
  `product_type` varchar(128) NOT NULL,
  `product_active` tinyint(4) NOT NULL,
  `channel_id` int(11) NOT NULL,
  `channel_name` varchar(256) NOT NULL,
  `channel_active` tinyint(4) NOT NULL,
  `product_key` varchar(256) DEFAULT NULL,
  `version_name` varchar(64) NOT NULL,
  `version_active` tinyint(4) NOT NULL,
  `userid` int(11) NOT NULL,
  `platform` varchar(128) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_segment_launch`
--

CREATE TABLE IF NOT EXISTS `razor_dim_segment_launch` (
  `segment_sk` int(11) NOT NULL,
  `segment_name` varchar(128) NOT NULL,
  `startvalue` int(11) NOT NULL,
  `endvalue` int(11) NOT NULL,
  `effective_date` date NOT NULL,
  `expiry_date` date NOT NULL
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_dim_segment_launch`
--

INSERT INTO `razor_dim_segment_launch` (`segment_sk`, `segment_name`, `startvalue`, `endvalue`, `effective_date`, `expiry_date`) VALUES
(1, '1-2', 1, 2, '0000-00-00', '9999-12-31'),
(2, '3-5', 3, 5, '0000-00-00', '9999-12-31'),
(3, '6-9', 6, 9, '0000-00-00', '9999-12-31'),
(4, '10-19', 10, 19, '0000-00-00', '9999-12-31'),
(5, '20-49', 20, 49, '0000-00-00', '9999-12-31'),
(6, '50', 50, 2147483647, '0000-00-00', '9999-12-31');

-- --------------------------------------------------------

--
-- 表的结构 `razor_dim_segment_usinglog`
--

CREATE TABLE IF NOT EXISTS `razor_dim_segment_usinglog` (
  `segment_sk` int(11) NOT NULL,
  `segment_name` varchar(128) NOT NULL,
  `startvalue` int(11) NOT NULL,
  `endvalue` int(11) NOT NULL,
  `effective_date` date NOT NULL,
  `expiry_date` date NOT NULL
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_dim_segment_usinglog`
--

INSERT INTO `razor_dim_segment_usinglog` (`segment_sk`, `segment_name`, `startvalue`, `endvalue`, `effective_date`, `expiry_date`) VALUES
(1, '0-3', 0, 3000, '0000-00-00', '9999-12-31'),
(2, '3-10', 3000, 10000, '0000-00-00', '9999-12-31'),
(3, '10-30', 10000, 30000, '0000-00-00', '9999-12-31'),
(4, '30-60', 30000, 60000, '0000-00-00', '9999-12-31'),
(5, '1-3', 60000, 180000, '0000-00-00', '9999-12-31'),
(6, '3-10', 180000, 600000, '0000-00-00', '9999-12-31'),
(7, '10-30', 600000, 1800000, '0000-00-00', '9999-12-31'),
(8, '30', 1800000, 2147483647, '0000-00-00', '9999-12-31');

-- --------------------------------------------------------

--
-- 表的结构 `razor_fact_clientdata`
--

CREATE TABLE IF NOT EXISTS `razor_fact_clientdata` (
  `dataid` int(11) NOT NULL,
  `product_sk` int(11) NOT NULL,
  `deviceos_sk` int(11) NOT NULL,
  `deviceresolution_sk` int(11) NOT NULL,
  `devicelanguage_sk` int(11) NOT NULL,
  `devicebrand_sk` int(11) NOT NULL,
  `devicesupplier_sk` int(11) NOT NULL,
  `location_sk` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `deviceidentifier` varchar(256) NOT NULL,
  `clientdataid` int(11) NOT NULL,
  `network_sk` int(11) NOT NULL,
  `hour_sk` int(11) NOT NULL,
  `isnew` tinyint(4) NOT NULL DEFAULT '1',
  `isnew_channel` tinyint(4) NOT NULL DEFAULT '1',
  `useridentifier` varchar(256) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_fact_errorlog`
--

CREATE TABLE IF NOT EXISTS `razor_fact_errorlog` (
  `errorid` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `product_sk` int(11) NOT NULL,
  `osversion_sk` int(11) NOT NULL,
  `title_sk` int(11) NOT NULL,
  `deviceidentifier` int(11) NOT NULL,
  `activity` varchar(512) NOT NULL,
  `time` datetime NOT NULL,
  `title` text NOT NULL,
  `stacktrace` text NOT NULL,
  `isfix` int(11) NOT NULL,
  `id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_fact_event`
--

CREATE TABLE IF NOT EXISTS `razor_fact_event` (
  `eventid` int(11) NOT NULL,
  `event_sk` int(11) NOT NULL,
  `product_sk` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `deviceid` varchar(50) DEFAULT NULL,
  `category` varchar(50) DEFAULT NULL,
  `event` varchar(50) NOT NULL,
  `label` varchar(50) DEFAULT NULL,
  `attachment` varchar(50) DEFAULT NULL,
  `clientdate` datetime NOT NULL,
  `number` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_fact_launch_daily`
--

CREATE TABLE IF NOT EXISTS `razor_fact_launch_daily` (
  `launchid` int(11) NOT NULL,
  `product_sk` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `segment_sk` int(11) NOT NULL DEFAULT '0',
  `accesscount` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_fact_usinglog`
--

CREATE TABLE IF NOT EXISTS `razor_fact_usinglog` (
  `usingid` int(11) NOT NULL,
  `product_sk` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `activity_sk` int(11) NOT NULL,
  `session_id` varchar(64) NOT NULL,
  `duration` int(11) NOT NULL,
  `activities` varchar(512) NOT NULL,
  `starttime` datetime NOT NULL,
  `endtime` datetime NOT NULL,
  `uid` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_fact_usinglog_daily`
--

CREATE TABLE IF NOT EXISTS `razor_fact_usinglog_daily` (
  `usingid` int(11) NOT NULL,
  `product_sk` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `session_id` varchar(64) NOT NULL,
  `segment_sk` int(11) NOT NULL DEFAULT '0',
  `duration` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_hour24`
--

CREATE TABLE IF NOT EXISTS `razor_hour24` (
  `hour` tinyint(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_hour24`
--

INSERT INTO `razor_hour24` (`hour`) VALUES
(0),
(1),
(2),
(3),
(4),
(5),
(6),
(7),
(8),
(9),
(10),
(11),
(12),
(13),
(14),
(15),
(16),
(17),
(18),
(19),
(20),
(21),
(22),
(23);

-- --------------------------------------------------------

--
-- 表的结构 `razor_log`
--

CREATE TABLE IF NOT EXISTS `razor_log` (
  `id` int(11) NOT NULL,
  `op_type` varchar(128) NOT NULL,
  `op_name` varchar(256) NOT NULL,
  `op_starttime` datetime DEFAULT NULL,
  `op_date` datetime DEFAULT NULL,
  `affected_rows` int(11) DEFAULT NULL,
  `duration` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_accesslevel`
--

CREATE TABLE IF NOT EXISTS `razor_sum_accesslevel` (
  `pid` int(11) NOT NULL,
  `product_sk` int(11) DEFAULT NULL,
  `fromid` int(11) NOT NULL,
  `toid` int(11) NOT NULL,
  `level` int(11) DEFAULT NULL,
  `count` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_accesspath`
--

CREATE TABLE IF NOT EXISTS `razor_sum_accesspath` (
  `pid` int(11) NOT NULL,
  `product_sk` int(11) DEFAULT NULL,
  `fromid` int(11) NOT NULL,
  `toid` int(11) NOT NULL,
  `jump` int(11) DEFAULT NULL,
  `count` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_basic_activeusers`
--

CREATE TABLE IF NOT EXISTS `razor_sum_basic_activeusers` (
  `product_id` int(11) NOT NULL,
  `week_activeuser` int(11) NOT NULL DEFAULT '0',
  `month_activeuser` int(11) NOT NULL DEFAULT '0',
  `week_percent` float NOT NULL DEFAULT '0',
  `month_percent` float NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_basic_byhour`
--

CREATE TABLE IF NOT EXISTS `razor_sum_basic_byhour` (
  `fid` int(11) NOT NULL,
  `product_sk` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `hour_sk` tinyint(11) NOT NULL,
  `sessions` int(11) NOT NULL DEFAULT '0',
  `startusers` int(11) NOT NULL DEFAULT '0',
  `newusers` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_basic_channel`
--

CREATE TABLE IF NOT EXISTS `razor_sum_basic_channel` (
  `sid` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `channel_id` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `sessions` int(11) NOT NULL DEFAULT '0',
  `startusers` int(11) NOT NULL DEFAULT '0',
  `newusers` int(11) NOT NULL DEFAULT '0',
  `upgradeusers` int(11) NOT NULL DEFAULT '0',
  `allusers` int(11) NOT NULL DEFAULT '0',
  `allsessions` int(11) NOT NULL DEFAULT '0',
  `usingtime` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_basic_channel_activeusers`
--

CREATE TABLE IF NOT EXISTS `razor_sum_basic_channel_activeusers` (
  `pid` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `channel_id` int(11) NOT NULL,
  `activeuser` int(11) NOT NULL DEFAULT '0',
  `percent` float NOT NULL DEFAULT '0',
  `flag` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_basic_product`
--

CREATE TABLE IF NOT EXISTS `razor_sum_basic_product` (
  `sid` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `sessions` int(11) NOT NULL DEFAULT '0',
  `startusers` int(11) NOT NULL DEFAULT '0',
  `newusers` int(11) NOT NULL DEFAULT '0',
  `upgradeusers` int(11) NOT NULL DEFAULT '0',
  `allusers` int(11) NOT NULL DEFAULT '0',
  `allsessions` int(11) NOT NULL DEFAULT '0',
  `usingtime` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_basic_product_version`
--

CREATE TABLE IF NOT EXISTS `razor_sum_basic_product_version` (
  `sid` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `version_name` varchar(64) NOT NULL,
  `sessions` int(11) NOT NULL DEFAULT '0',
  `startusers` int(11) NOT NULL DEFAULT '0',
  `newusers` int(11) NOT NULL DEFAULT '0',
  `upgradeusers` int(11) NOT NULL DEFAULT '0',
  `allusers` int(11) NOT NULL DEFAULT '0',
  `allsessions` int(11) NOT NULL DEFAULT '0',
  `usingtime` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_devicebrand`
--

CREATE TABLE IF NOT EXISTS `razor_sum_devicebrand` (
  `did` int(11) unsigned NOT NULL,
  `product_id` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `devicebrand_sk` int(11) NOT NULL,
  `sessions` int(11) NOT NULL DEFAULT '0',
  `newusers` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_devicenetwork`
--

CREATE TABLE IF NOT EXISTS `razor_sum_devicenetwork` (
  `did` int(11) unsigned NOT NULL,
  `product_id` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `devicenetwork_sk` int(11) NOT NULL,
  `sessions` int(11) NOT NULL DEFAULT '0',
  `newusers` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_deviceos`
--

CREATE TABLE IF NOT EXISTS `razor_sum_deviceos` (
  `did` int(11) unsigned NOT NULL,
  `product_id` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `deviceos_sk` int(11) NOT NULL,
  `sessions` int(11) NOT NULL DEFAULT '0',
  `newusers` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_deviceresolution`
--

CREATE TABLE IF NOT EXISTS `razor_sum_deviceresolution` (
  `did` int(11) unsigned NOT NULL,
  `product_id` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `deviceresolution_sk` int(11) NOT NULL,
  `sessions` int(11) NOT NULL DEFAULT '0',
  `newusers` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_devicesupplier`
--

CREATE TABLE IF NOT EXISTS `razor_sum_devicesupplier` (
  `did` int(11) unsigned NOT NULL,
  `product_id` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `devicesupplier_sk` int(11) NOT NULL,
  `sessions` int(11) NOT NULL DEFAULT '0',
  `newusers` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_event`
--

CREATE TABLE IF NOT EXISTS `razor_sum_event` (
  `eid` int(11) unsigned NOT NULL,
  `product_sk` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `event_sk` int(11) NOT NULL,
  `total` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_location`
--

CREATE TABLE IF NOT EXISTS `razor_sum_location` (
  `lid` int(11) unsigned NOT NULL,
  `product_id` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `location_sk` int(11) NOT NULL,
  `sessions` int(11) NOT NULL DEFAULT '0',
  `newusers` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_reserveusers_daily`
--

CREATE TABLE IF NOT EXISTS `razor_sum_reserveusers_daily` (
  `rid` int(11) NOT NULL,
  `startdate_sk` int(11) NOT NULL,
  `enddate_sk` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `version_name` varchar(128) NOT NULL,
  `channel_name` varchar(128) NOT NULL,
  `usercount` int(11) NOT NULL DEFAULT '0',
  `day1` int(11) NOT NULL DEFAULT '0',
  `day2` int(11) NOT NULL DEFAULT '0',
  `day3` int(11) NOT NULL DEFAULT '0',
  `day4` int(11) NOT NULL DEFAULT '0',
  `day5` int(11) NOT NULL DEFAULT '0',
  `day6` int(11) NOT NULL DEFAULT '0',
  `day7` int(11) NOT NULL DEFAULT '0',
  `day8` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_reserveusers_monthly`
--

CREATE TABLE IF NOT EXISTS `razor_sum_reserveusers_monthly` (
  `rid` int(11) NOT NULL,
  `startdate_sk` int(11) NOT NULL,
  `enddate_sk` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `version_name` varchar(128) NOT NULL,
  `channel_name` varchar(128) NOT NULL,
  `usercount` int(11) NOT NULL DEFAULT '0',
  `month1` int(11) NOT NULL DEFAULT '0',
  `month2` int(11) NOT NULL DEFAULT '0',
  `month3` int(11) NOT NULL DEFAULT '0',
  `month4` int(11) NOT NULL DEFAULT '0',
  `month5` int(11) NOT NULL DEFAULT '0',
  `month6` int(11) NOT NULL DEFAULT '0',
  `month7` int(11) NOT NULL DEFAULT '0',
  `month8` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_reserveusers_weekly`
--

CREATE TABLE IF NOT EXISTS `razor_sum_reserveusers_weekly` (
  `rid` int(11) NOT NULL,
  `startdate_sk` int(11) NOT NULL,
  `enddate_sk` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `version_name` varchar(128) NOT NULL,
  `channel_name` varchar(128) NOT NULL,
  `usercount` int(11) NOT NULL DEFAULT '0',
  `week1` int(11) NOT NULL DEFAULT '0',
  `week2` int(11) NOT NULL DEFAULT '0',
  `week3` int(11) NOT NULL DEFAULT '0',
  `week4` int(11) NOT NULL DEFAULT '0',
  `week5` int(11) NOT NULL DEFAULT '0',
  `week6` int(11) NOT NULL DEFAULT '0',
  `week7` int(11) NOT NULL DEFAULT '0',
  `week8` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_sum_usinglog_activity`
--

CREATE TABLE IF NOT EXISTS `razor_sum_usinglog_activity` (
  `usingid` int(11) NOT NULL,
  `date_sk` int(11) NOT NULL,
  `product_sk` int(11) NOT NULL,
  `activity_sk` int(11) DEFAULT NULL,
  `accesscount` int(11) NOT NULL DEFAULT '0',
  `totaltime` int(11) NOT NULL DEFAULT '0',
  `exitcount` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `razor_deviceid_pushid`
--
ALTER TABLE `razor_deviceid_pushid`
  ADD PRIMARY KEY (`did`),
  ADD UNIQUE KEY `deviceid` (`deviceid`,`pushid`),
  ADD KEY `pushid` (`pushid`);

--
-- Indexes for table `razor_deviceid_userid`
--
ALTER TABLE `razor_deviceid_userid`
  ADD PRIMARY KEY (`did`),
  ADD UNIQUE KEY `deviceid` (`deviceid`,`userid`),
  ADD KEY `userid` (`userid`);

--
-- Indexes for table `razor_dim_activity`
--
ALTER TABLE `razor_dim_activity`
  ADD PRIMARY KEY (`activity_sk`),
  ADD KEY `activity_name` (`activity_name`(255),`product_id`);

--
-- Indexes for table `razor_dim_date`
--
ALTER TABLE `razor_dim_date`
  ADD PRIMARY KEY (`date_sk`),
  ADD KEY `year` (`year`,`month`,`day`),
  ADD KEY `year_2` (`year`,`week`),
  ADD KEY `datevalue` (`datevalue`);

--
-- Indexes for table `razor_dim_devicebrand`
--
ALTER TABLE `razor_dim_devicebrand`
  ADD PRIMARY KEY (`devicebrand_sk`),
  ADD KEY `devicebrand_name` (`devicebrand_name`);

--
-- Indexes for table `razor_dim_devicelanguage`
--
ALTER TABLE `razor_dim_devicelanguage`
  ADD PRIMARY KEY (`devicelanguage_sk`),
  ADD KEY `devicelanguage_name` (`devicelanguage_name`);

--
-- Indexes for table `razor_dim_deviceos`
--
ALTER TABLE `razor_dim_deviceos`
  ADD PRIMARY KEY (`deviceos_sk`),
  ADD KEY `deviceos_name` (`deviceos_name`(255));

--
-- Indexes for table `razor_dim_deviceresolution`
--
ALTER TABLE `razor_dim_deviceresolution`
  ADD PRIMARY KEY (`deviceresolution_sk`),
  ADD KEY `deviceresolution_name` (`deviceresolution_name`);

--
-- Indexes for table `razor_dim_devicesupplier`
--
ALTER TABLE `razor_dim_devicesupplier`
  ADD PRIMARY KEY (`devicesupplier_sk`),
  ADD KEY `devicesupplier_name` (`devicesupplier_name`),
  ADD KEY `mccmnc` (`mccmnc`);

--
-- Indexes for table `razor_dim_errortitle`
--
ALTER TABLE `razor_dim_errortitle`
  ADD PRIMARY KEY (`title_sk`),
  ADD KEY `title_name` (`title_name`(255));

--
-- Indexes for table `razor_dim_event`
--
ALTER TABLE `razor_dim_event`
  ADD PRIMARY KEY (`event_sk`);

--
-- Indexes for table `razor_dim_location`
--
ALTER TABLE `razor_dim_location`
  ADD PRIMARY KEY (`location_sk`),
  ADD KEY `country` (`country`,`region`,`city`);

--
-- Indexes for table `razor_dim_network`
--
ALTER TABLE `razor_dim_network`
  ADD PRIMARY KEY (`network_sk`);

--
-- Indexes for table `razor_dim_product`
--
ALTER TABLE `razor_dim_product`
  ADD PRIMARY KEY (`product_sk`),
  ADD UNIQUE KEY `product_id` (`product_id`,`channel_id`,`version_name`,`userid`);

--
-- Indexes for table `razor_dim_segment_launch`
--
ALTER TABLE `razor_dim_segment_launch`
  ADD PRIMARY KEY (`segment_sk`);

--
-- Indexes for table `razor_dim_segment_usinglog`
--
ALTER TABLE `razor_dim_segment_usinglog`
  ADD PRIMARY KEY (`segment_sk`);

--
-- Indexes for table `razor_fact_clientdata`
--
ALTER TABLE `razor_fact_clientdata`
  ADD PRIMARY KEY (`dataid`),
  ADD KEY `deviceidentifier` (`deviceidentifier`(255)),
  ADD KEY `product_sk` (`product_sk`,`date_sk`,`deviceidentifier`(255));

--
-- Indexes for table `razor_fact_errorlog`
--
ALTER TABLE `razor_fact_errorlog`
  ADD PRIMARY KEY (`errorid`);

--
-- Indexes for table `razor_fact_event`
--
ALTER TABLE `razor_fact_event`
  ADD PRIMARY KEY (`eventid`),
  ADD KEY `date_sk` (`date_sk`,`product_sk`);

--
-- Indexes for table `razor_fact_launch_daily`
--
ALTER TABLE `razor_fact_launch_daily`
  ADD PRIMARY KEY (`launchid`),
  ADD UNIQUE KEY `product_sk` (`product_sk`,`date_sk`,`segment_sk`);

--
-- Indexes for table `razor_fact_usinglog`
--
ALTER TABLE `razor_fact_usinglog`
  ADD PRIMARY KEY (`usingid`);

--
-- Indexes for table `razor_fact_usinglog_daily`
--
ALTER TABLE `razor_fact_usinglog_daily`
  ADD PRIMARY KEY (`usingid`),
  ADD UNIQUE KEY `product_sk` (`product_sk`,`date_sk`,`session_id`);

--
-- Indexes for table `razor_hour24`
--
ALTER TABLE `razor_hour24`
  ADD PRIMARY KEY (`hour`);

--
-- Indexes for table `razor_log`
--
ALTER TABLE `razor_log`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_sum_accesslevel`
--
ALTER TABLE `razor_sum_accesslevel`
  ADD PRIMARY KEY (`pid`),
  ADD UNIQUE KEY `date_sk` (`product_sk`,`fromid`,`toid`,`level`);

--
-- Indexes for table `razor_sum_accesspath`
--
ALTER TABLE `razor_sum_accesspath`
  ADD PRIMARY KEY (`pid`),
  ADD UNIQUE KEY `date_sk` (`product_sk`,`fromid`,`toid`,`jump`);

--
-- Indexes for table `razor_sum_basic_activeusers`
--
ALTER TABLE `razor_sum_basic_activeusers`
  ADD PRIMARY KEY (`product_id`);

--
-- Indexes for table `razor_sum_basic_byhour`
--
ALTER TABLE `razor_sum_basic_byhour`
  ADD PRIMARY KEY (`fid`),
  ADD UNIQUE KEY `product_sk` (`product_sk`,`date_sk`,`hour_sk`);

--
-- Indexes for table `razor_sum_basic_channel`
--
ALTER TABLE `razor_sum_basic_channel`
  ADD PRIMARY KEY (`sid`),
  ADD UNIQUE KEY `channel_id` (`product_id`,`channel_id`,`date_sk`);

--
-- Indexes for table `razor_sum_basic_channel_activeusers`
--
ALTER TABLE `razor_sum_basic_channel_activeusers`
  ADD PRIMARY KEY (`pid`),
  ADD UNIQUE KEY `date_sk` (`date_sk`,`product_id`,`channel_id`,`flag`);

--
-- Indexes for table `razor_sum_basic_product`
--
ALTER TABLE `razor_sum_basic_product`
  ADD PRIMARY KEY (`sid`),
  ADD UNIQUE KEY `product_id` (`product_id`,`date_sk`);

--
-- Indexes for table `razor_sum_basic_product_version`
--
ALTER TABLE `razor_sum_basic_product_version`
  ADD PRIMARY KEY (`sid`),
  ADD UNIQUE KEY `product_id` (`product_id`,`date_sk`,`version_name`);

--
-- Indexes for table `razor_sum_devicebrand`
--
ALTER TABLE `razor_sum_devicebrand`
  ADD PRIMARY KEY (`did`),
  ADD UNIQUE KEY `index_devicebrand` (`product_id`,`date_sk`,`devicebrand_sk`);

--
-- Indexes for table `razor_sum_devicenetwork`
--
ALTER TABLE `razor_sum_devicenetwork`
  ADD PRIMARY KEY (`did`),
  ADD UNIQUE KEY `index_devicenetwork` (`product_id`,`date_sk`,`devicenetwork_sk`);

--
-- Indexes for table `razor_sum_deviceos`
--
ALTER TABLE `razor_sum_deviceos`
  ADD PRIMARY KEY (`did`),
  ADD UNIQUE KEY `index_deviceos` (`product_id`,`date_sk`,`deviceos_sk`);

--
-- Indexes for table `razor_sum_deviceresolution`
--
ALTER TABLE `razor_sum_deviceresolution`
  ADD PRIMARY KEY (`did`),
  ADD UNIQUE KEY `index_deviceresolution` (`product_id`,`date_sk`,`deviceresolution_sk`);

--
-- Indexes for table `razor_sum_devicesupplier`
--
ALTER TABLE `razor_sum_devicesupplier`
  ADD PRIMARY KEY (`did`),
  ADD UNIQUE KEY `index_devicesupplier` (`product_id`,`date_sk`,`devicesupplier_sk`);

--
-- Indexes for table `razor_sum_event`
--
ALTER TABLE `razor_sum_event`
  ADD PRIMARY KEY (`eid`),
  ADD UNIQUE KEY `product_sk` (`product_sk`,`date_sk`,`event_sk`);

--
-- Indexes for table `razor_sum_location`
--
ALTER TABLE `razor_sum_location`
  ADD PRIMARY KEY (`lid`),
  ADD UNIQUE KEY `index_location` (`product_id`,`date_sk`,`location_sk`);

--
-- Indexes for table `razor_sum_reserveusers_daily`
--
ALTER TABLE `razor_sum_reserveusers_daily`
  ADD PRIMARY KEY (`rid`),
  ADD UNIQUE KEY `startdate_sk` (`startdate_sk`,`enddate_sk`,`product_id`,`version_name`,`channel_name`);

--
-- Indexes for table `razor_sum_reserveusers_monthly`
--
ALTER TABLE `razor_sum_reserveusers_monthly`
  ADD PRIMARY KEY (`rid`),
  ADD UNIQUE KEY `startdate_sk` (`startdate_sk`,`enddate_sk`,`product_id`,`version_name`,`channel_name`);

--
-- Indexes for table `razor_sum_reserveusers_weekly`
--
ALTER TABLE `razor_sum_reserveusers_weekly`
  ADD PRIMARY KEY (`rid`),
  ADD UNIQUE KEY `startdate_sk` (`startdate_sk`,`enddate_sk`,`product_id`,`version_name`,`channel_name`);

--
-- Indexes for table `razor_sum_usinglog_activity`
--
ALTER TABLE `razor_sum_usinglog_activity`
  ADD PRIMARY KEY (`usingid`),
  ADD UNIQUE KEY `date_sk` (`date_sk`,`product_sk`,`activity_sk`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `razor_deviceid_pushid`
--
ALTER TABLE `razor_deviceid_pushid`
  MODIFY `did` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_deviceid_userid`
--
ALTER TABLE `razor_deviceid_userid`
  MODIFY `did` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_dim_activity`
--
ALTER TABLE `razor_dim_activity`
  MODIFY `activity_sk` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_dim_date`
--
ALTER TABLE `razor_dim_date`
  MODIFY `date_sk` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=4019;
--
-- AUTO_INCREMENT for table `razor_dim_devicebrand`
--
ALTER TABLE `razor_dim_devicebrand`
  MODIFY `devicebrand_sk` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_dim_devicelanguage`
--
ALTER TABLE `razor_dim_devicelanguage`
  MODIFY `devicelanguage_sk` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_dim_deviceos`
--
ALTER TABLE `razor_dim_deviceos`
  MODIFY `deviceos_sk` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_dim_deviceresolution`
--
ALTER TABLE `razor_dim_deviceresolution`
  MODIFY `deviceresolution_sk` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_dim_devicesupplier`
--
ALTER TABLE `razor_dim_devicesupplier`
  MODIFY `devicesupplier_sk` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=1068;
--
-- AUTO_INCREMENT for table `razor_dim_errortitle`
--
ALTER TABLE `razor_dim_errortitle`
  MODIFY `title_sk` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_dim_event`
--
ALTER TABLE `razor_dim_event`
  MODIFY `event_sk` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_dim_location`
--
ALTER TABLE `razor_dim_location`
  MODIFY `location_sk` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_dim_network`
--
ALTER TABLE `razor_dim_network`
  MODIFY `network_sk` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_dim_product`
--
ALTER TABLE `razor_dim_product`
  MODIFY `product_sk` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_dim_segment_launch`
--
ALTER TABLE `razor_dim_segment_launch`
  MODIFY `segment_sk` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=7;
--
-- AUTO_INCREMENT for table `razor_dim_segment_usinglog`
--
ALTER TABLE `razor_dim_segment_usinglog`
  MODIFY `segment_sk` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=9;
--
-- AUTO_INCREMENT for table `razor_fact_clientdata`
--
ALTER TABLE `razor_fact_clientdata`
  MODIFY `dataid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_fact_errorlog`
--
ALTER TABLE `razor_fact_errorlog`
  MODIFY `errorid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_fact_event`
--
ALTER TABLE `razor_fact_event`
  MODIFY `eventid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_fact_launch_daily`
--
ALTER TABLE `razor_fact_launch_daily`
  MODIFY `launchid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_fact_usinglog`
--
ALTER TABLE `razor_fact_usinglog`
  MODIFY `usingid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_fact_usinglog_daily`
--
ALTER TABLE `razor_fact_usinglog_daily`
  MODIFY `usingid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_log`
--
ALTER TABLE `razor_log`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_accesslevel`
--
ALTER TABLE `razor_sum_accesslevel`
  MODIFY `pid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_accesspath`
--
ALTER TABLE `razor_sum_accesspath`
  MODIFY `pid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_basic_byhour`
--
ALTER TABLE `razor_sum_basic_byhour`
  MODIFY `fid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_basic_channel`
--
ALTER TABLE `razor_sum_basic_channel`
  MODIFY `sid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_basic_channel_activeusers`
--
ALTER TABLE `razor_sum_basic_channel_activeusers`
  MODIFY `pid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_basic_product`
--
ALTER TABLE `razor_sum_basic_product`
  MODIFY `sid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_basic_product_version`
--
ALTER TABLE `razor_sum_basic_product_version`
  MODIFY `sid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_devicebrand`
--
ALTER TABLE `razor_sum_devicebrand`
  MODIFY `did` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_devicenetwork`
--
ALTER TABLE `razor_sum_devicenetwork`
  MODIFY `did` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_deviceos`
--
ALTER TABLE `razor_sum_deviceos`
  MODIFY `did` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_deviceresolution`
--
ALTER TABLE `razor_sum_deviceresolution`
  MODIFY `did` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_devicesupplier`
--
ALTER TABLE `razor_sum_devicesupplier`
  MODIFY `did` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_event`
--
ALTER TABLE `razor_sum_event`
  MODIFY `eid` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_location`
--
ALTER TABLE `razor_sum_location`
  MODIFY `lid` int(11) unsigned NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_reserveusers_daily`
--
ALTER TABLE `razor_sum_reserveusers_daily`
  MODIFY `rid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_reserveusers_monthly`
--
ALTER TABLE `razor_sum_reserveusers_monthly`
  MODIFY `rid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_reserveusers_weekly`
--
ALTER TABLE `razor_sum_reserveusers_weekly`
  MODIFY `rid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_sum_usinglog_activity`
--
ALTER TABLE `razor_sum_usinglog_activity`
  MODIFY `usingid` int(11) NOT NULL AUTO_INCREMENT;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
