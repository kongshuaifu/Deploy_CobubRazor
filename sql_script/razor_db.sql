-- phpMyAdmin SQL Dump
-- version 4.4.14
-- http://www.phpmyadmin.net
--
-- Host: 127.0.0.1
-- Generation Time: 2017-07-25 17:25:37
-- 服务器版本： 5.6.26
-- PHP Version: 5.6.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `razor_db`
--
USE razor_db;

-- --------------------------------------------------------

--
-- 表的结构 `razor_alert`
--

CREATE TABLE IF NOT EXISTS `razor_alert` (
  `id` int(50) NOT NULL,
  `userid` int(50) NOT NULL,
  `productid` int(50) NOT NULL,
  `condition` float NOT NULL,
  `label` varchar(50) NOT NULL,
  `active` int(10) NOT NULL DEFAULT '1',
  `emails` varchar(256) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_alertdetail`
--

CREATE TABLE IF NOT EXISTS `razor_alertdetail` (
  `id` int(50) NOT NULL,
  `alertlabel` int(50) NOT NULL,
  `factdata` int(50) NOT NULL,
  `forecastdata` int(50) NOT NULL,
  `time` datetime NOT NULL,
  `states` int(10) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_cell_towers`
--

CREATE TABLE IF NOT EXISTS `razor_cell_towers` (
  `id` int(10) NOT NULL,
  `clientdataid` int(50) NOT NULL,
  `cellid` varchar(50) NOT NULL,
  `lac` varchar(50) NOT NULL,
  `mcc` varchar(50) NOT NULL,
  `mnc` varchar(50) NOT NULL,
  `age` varchar(50) NOT NULL,
  `signalstrength` varchar(50) NOT NULL,
  `timingadvance` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_channel`
--

CREATE TABLE IF NOT EXISTS `razor_channel` (
  `channel_id` int(11) NOT NULL,
  `channel_name` varchar(255) NOT NULL DEFAULT '',
  `create_date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `user_id` int(11) NOT NULL DEFAULT '1',
  `type` enum('system','user') NOT NULL DEFAULT 'user',
  `platform` int(10) NOT NULL,
  `active` int(10) NOT NULL DEFAULT '1'
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_channel`
--

INSERT INTO `razor_channel` (`channel_id`, `channel_name`, `create_date`, `user_id`, `type`, `platform`, `active`) VALUES
(1, '安卓市场', '2011-11-22 13:54:39', 1, 'system', 1, 1),
(2, '机锋市场', '2011-11-22 13:54:47', 1, 'system', 1, 1),
(3, '安智市场', '2011-11-22 13:54:57', 1, 'system', 1, 1),
(4, 'XDA市场', '2011-11-22 13:55:03', 1, 'system', 1, 1),
(5, 'AppStore', '2011-12-03 13:49:25', 1, 'system', 2, 1),
(6, 'Windows Phone Store', '2011-12-03 13:49:25', 1, 'system', 3, 1);

-- --------------------------------------------------------

--
-- 表的结构 `razor_channel_product`
--

CREATE TABLE IF NOT EXISTS `razor_channel_product` (
  `cp_id` int(11) NOT NULL,
  `description` varchar(5000) DEFAULT NULL,
  `updateurl` varchar(2000) NOT NULL DEFAULT '',
  `entrypoint` varchar(500) NOT NULL DEFAULT '',
  `location` varchar(500) NOT NULL DEFAULT '',
  `version` varchar(50) NOT NULL DEFAULT '',
  `date` datetime NOT NULL,
  `productkey` varchar(50) NOT NULL,
  `man` tinyint(1) NOT NULL DEFAULT '0',
  `user_id` int(11) NOT NULL DEFAULT '1',
  `product_id` int(11) NOT NULL DEFAULT '0',
  `channel_id` int(11) NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_ci_sessions`
--

CREATE TABLE IF NOT EXISTS `razor_ci_sessions` (
  `session_id` varchar(40) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '0',
  `ip_address` varchar(45) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT '0',
  `user_agent` varchar(150) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `last_activity` int(10) unsigned NOT NULL DEFAULT '0',
  `user_data` text CHARACTER SET utf8 COLLATE utf8_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_ci_sessions`
--

INSERT INTO `razor_ci_sessions` (`session_id`, `ip_address`, `user_agent`, `last_activity`, `user_data`) VALUES
('3d742f020f8c55d0cb6398775ca72fcc', '0.0.0.0', 'Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:54.0) Gecko/20100101 Firefox/54.0', 1500974597, 'a:4:{s:9:"user_data";s:0:"";s:7:"user_id";s:1:"1";s:8:"username";s:5:"admin";s:6:"status";s:1:"1";}');

-- --------------------------------------------------------

--
-- 表的结构 `razor_clientdata`
--

CREATE TABLE IF NOT EXISTS `razor_clientdata` (
  `id` int(11) NOT NULL,
  `serviceversion` varchar(50) DEFAULT NULL,
  `name` varchar(50) DEFAULT NULL,
  `version` varchar(50) DEFAULT NULL,
  `platform` varchar(16) DEFAULT NULL,
  `osversion` varchar(50) DEFAULT NULL,
  `osaddtional` varchar(50) DEFAULT NULL,
  `language` varchar(50) DEFAULT NULL,
  `resolution` varchar(50) DEFAULT NULL,
  `ismobiledevice` varchar(50) DEFAULT NULL,
  `devicename` varchar(50) DEFAULT NULL,
  `deviceid` varchar(128) DEFAULT NULL,
  `defaultbrowser` varchar(50) DEFAULT NULL,
  `javasupport` varchar(50) DEFAULT NULL,
  `flashversion` varchar(50) DEFAULT NULL,
  `modulename` varchar(50) DEFAULT NULL,
  `imei` varchar(50) DEFAULT NULL,
  `imsi` varchar(50) DEFAULT NULL,
  `salt` varchar(64) DEFAULT NULL,
  `havegps` varchar(50) DEFAULT NULL,
  `havebt` varchar(50) DEFAULT NULL,
  `havewifi` varchar(50) DEFAULT NULL,
  `havegravity` varchar(50) DEFAULT NULL,
  `wifimac` varchar(50) DEFAULT NULL,
  `latitude` varchar(50) DEFAULT NULL,
  `longitude` varchar(50) DEFAULT NULL,
  `date` datetime NOT NULL,
  `clientip` varchar(50) NOT NULL,
  `productkey` varchar(50) NOT NULL,
  `service_supplier` varchar(64) DEFAULT NULL,
  `country` varchar(50) DEFAULT 'unknown',
  `region` varchar(50) DEFAULT 'unknown',
  `city` varchar(50) DEFAULT 'unknown',
  `street` varchar(500) DEFAULT NULL,
  `streetno` varchar(50) DEFAULT NULL,
  `postcode` varchar(50) DEFAULT NULL,
  `network` varchar(128) NOT NULL DEFAULT '1',
  `isjailbroken` int(10) NOT NULL DEFAULT '0',
  `insertdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `useridentifier` varchar(64) DEFAULT NULL,
  `session_id` varchar(32) DEFAULT NULL,
  `lib_version` varchar(16) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_clientusinglog`
--

CREATE TABLE IF NOT EXISTS `razor_clientusinglog` (
  `id` int(11) NOT NULL,
  `session_id` varchar(32) NOT NULL,
  `start_millis` datetime NOT NULL,
  `end_millis` datetime NOT NULL,
  `duration` int(50) NOT NULL,
  `activities` varchar(500) NOT NULL,
  `appkey` varchar(64) NOT NULL,
  `version` varchar(50) NOT NULL,
  `deviceid` varchar(128) DEFAULT NULL,
  `useridentifier` varchar(64) DEFAULT NULL,
  `lib_version` varchar(16) DEFAULT NULL,
  `insertdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_config`
--

CREATE TABLE IF NOT EXISTS `razor_config` (
  `id` int(50) NOT NULL,
  `autogetlocation` tinyint(1) NOT NULL DEFAULT '1',
  `updateonlywifi` tinyint(1) NOT NULL DEFAULT '1',
  `product_id` int(50) NOT NULL,
  `sessionmillis` int(50) NOT NULL DEFAULT '30',
  `reportpolicy` int(11) NOT NULL DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_device_tag`
--

CREATE TABLE IF NOT EXISTS `razor_device_tag` (
  `id` int(11) NOT NULL,
  `deviceid` varchar(256) NOT NULL,
  `tags` varchar(1024) DEFAULT NULL,
  `appkey` varchar(64) NOT NULL,
  `useridentifier` varchar(32) DEFAULT NULL,
  `lib_version` varchar(32) DEFAULT NULL,
  `insertdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_errorlog`
--

CREATE TABLE IF NOT EXISTS `razor_errorlog` (
  `id` int(50) NOT NULL,
  `appkey` varchar(50) NOT NULL,
  `device` varchar(64) NOT NULL,
  `os_version` varchar(50) NOT NULL,
  `activity` varchar(50) NOT NULL,
  `time` datetime NOT NULL,
  `title` text NOT NULL,
  `stacktrace` text NOT NULL,
  `version` varchar(32) NOT NULL,
  `isfix` int(11) DEFAULT '0',
  `error_type` int(11) DEFAULT '0',
  `session_id` varchar(32) DEFAULT NULL,
  `useridentifier` varchar(32) DEFAULT NULL,
  `lib_version` varchar(16) DEFAULT NULL,
  `deviceid` varchar(32) DEFAULT NULL,
  `dsymid` varchar(64) DEFAULT NULL,
  `cpt` varchar(64) DEFAULT NULL,
  `bim` varchar(64) DEFAULT NULL,
  `insertdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_eventdata`
--

CREATE TABLE IF NOT EXISTS `razor_eventdata` (
  `id` int(11) NOT NULL,
  `deviceid` varchar(128) DEFAULT NULL,
  `category` varchar(50) DEFAULT NULL,
  `event` varchar(50) DEFAULT NULL,
  `label` varchar(50) DEFAULT NULL,
  `attachment` varchar(512) DEFAULT NULL,
  `clientdate` datetime NOT NULL,
  `productkey` varchar(64) NOT NULL DEFAULT 'no_key',
  `num` int(50) NOT NULL DEFAULT '1',
  `event_id` int(50) NOT NULL,
  `version` varchar(50) NOT NULL,
  `useridentifier` varchar(64) DEFAULT NULL,
  `session_id` varchar(32) DEFAULT NULL,
  `lib_version` varchar(16) DEFAULT NULL,
  `insertdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_event_defination`
--

CREATE TABLE IF NOT EXISTS `razor_event_defination` (
  `event_id` int(11) NOT NULL,
  `event_identifier` varchar(50) NOT NULL,
  `productkey` char(50) NOT NULL,
  `event_name` char(50) NOT NULL,
  `channel_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `create_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `active` int(10) NOT NULL DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_getui_product`
--

CREATE TABLE IF NOT EXISTS `razor_getui_product` (
  `id` int(11) NOT NULL,
  `product_id` int(11) DEFAULT NULL,
  `is_active` tinyint(4) DEFAULT NULL,
  `app_id` varchar(25) DEFAULT NULL,
  `user_id` int(8) DEFAULT NULL,
  `app_key` varchar(25) NOT NULL,
  `app_secret` varchar(25) NOT NULL,
  `app_mastersecret` varchar(25) NOT NULL,
  `app_identifier` varchar(25) NOT NULL,
  `activate_date` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_login_attempts`
--

CREATE TABLE IF NOT EXISTS `razor_login_attempts` (
  `id` int(11) NOT NULL,
  `ip_address` varchar(40) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `login` varchar(50) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_markevent`
--

CREATE TABLE IF NOT EXISTS `razor_markevent` (
  `id` int(50) NOT NULL,
  `userid` int(50) NOT NULL,
  `productid` int(50) NOT NULL DEFAULT '-1',
  `title` varchar(45) NOT NULL,
  `description` varchar(128) NOT NULL,
  `private` tinyint(1) NOT NULL DEFAULT '0',
  `marktime` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_networktype`
--

CREATE TABLE IF NOT EXISTS `razor_networktype` (
  `id` int(8) NOT NULL,
  `type` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_networktype`
--

INSERT INTO `razor_networktype` (`id`, `type`) VALUES
(1, 'WIFI'),
(2, '2G/3G'),
(3, '1xRTT'),
(4, 'CDMA'),
(5, 'EDGE'),
(6, 'EVDO_0'),
(7, 'EVDO_A'),
(8, 'GPRS'),
(9, 'HSDPA'),
(10, 'HSPA'),
(11, 'HSUPA'),
(12, 'UMTS'),
(13, 'EHRPD'),
(14, 'EVDO_B'),
(15, 'HSPAP'),
(16, 'IDEN'),
(17, 'LTE'),
(18, 'UNKNOWN');

-- --------------------------------------------------------

--
-- 表的结构 `razor_platform`
--

CREATE TABLE IF NOT EXISTS `razor_platform` (
  `id` int(50) NOT NULL,
  `name` varchar(50) NOT NULL
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_platform`
--

INSERT INTO `razor_platform` (`id`, `name`) VALUES
(1, 'Android'),
(2, 'iOS'),
(3, 'Windows Phone');

-- --------------------------------------------------------

--
-- 表的结构 `razor_plugins`
--

CREATE TABLE IF NOT EXISTS `razor_plugins` (
  `id` int(11) NOT NULL,
  `identifier` varchar(50) NOT NULL,
  `user_id` int(50) NOT NULL,
  `status` int(10) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_product`
--

CREATE TABLE IF NOT EXISTS `razor_product` (
  `id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `description` varchar(5000) NOT NULL,
  `date` datetime NOT NULL,
  `user_id` int(11) NOT NULL DEFAULT '1',
  `channel_count` int(11) NOT NULL DEFAULT '0',
  `product_key` varchar(50) NOT NULL,
  `product_platform` int(50) NOT NULL DEFAULT '1',
  `category` int(50) NOT NULL DEFAULT '1',
  `active` int(11) NOT NULL DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_productfiles`
--

CREATE TABLE IF NOT EXISTS `razor_productfiles` (
  `id` int(11) NOT NULL,
  `productid` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `version` double NOT NULL,
  `type` varchar(50) NOT NULL,
  `updatedate` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_product_category`
--

CREATE TABLE IF NOT EXISTS `razor_product_category` (
  `id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL,
  `level` int(50) NOT NULL DEFAULT '1',
  `parentid` int(11) NOT NULL DEFAULT '0',
  `active` int(10) NOT NULL DEFAULT '1'
) ENGINE=InnoDB AUTO_INCREMENT=34 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_product_category`
--

INSERT INTO `razor_product_category` (`id`, `name`, `level`, `parentid`, `active`) VALUES
(1, '报刊杂志', 1, 0, 1),
(2, '社交', 1, 0, 1),
(3, '商业', 1, 0, 1),
(4, '财务', 1, 0, 1),
(5, '参考', 1, 0, 1),
(6, '导航', 1, 0, 1),
(7, '工具', 1, 0, 1),
(8, '健康健美', 1, 0, 1),
(9, '教育', 1, 0, 1),
(10, '旅行', 1, 0, 1),
(11, '摄影与录像', 1, 0, 1),
(12, '生活', 1, 0, 1),
(13, '体育', 1, 0, 1),
(14, '天气', 1, 0, 1),
(15, '图书', 1, 0, 1),
(16, '效率', 1, 0, 1),
(17, '新闻', 1, 0, 1),
(18, '音乐', 1, 0, 1),
(19, '医疗', 1, 0, 1),
(32, '娱乐', 1, 0, 1),
(33, '游戏', 1, 0, 1);

-- --------------------------------------------------------

--
-- 表的结构 `razor_product_version`
--

CREATE TABLE IF NOT EXISTS `razor_product_version` (
  `id` int(50) NOT NULL,
  `version` varchar(50) NOT NULL,
  `product_channel_id` int(50) NOT NULL,
  `updateurl` varchar(2000) NOT NULL,
  `updatetime` datetime NOT NULL,
  `description` varchar(5000) NOT NULL,
  `active` int(11) NOT NULL DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_reportlayout`
--

CREATE TABLE IF NOT EXISTS `razor_reportlayout` (
  `id` int(50) NOT NULL,
  `userid` int(50) NOT NULL,
  `productid` int(50) NOT NULL,
  `reportname` varchar(128) NOT NULL,
  `controller` varchar(128) NOT NULL,
  `method` varchar(45) DEFAULT NULL,
  `height` int(50) NOT NULL,
  `src` varchar(512) NOT NULL,
  `location` int(50) NOT NULL,
  `type` int(10) NOT NULL,
  `createtime` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_tag_group`
--

CREATE TABLE IF NOT EXISTS `razor_tag_group` (
  `id` int(4) NOT NULL,
  `product_id` int(4) NOT NULL,
  `name` varchar(200) NOT NULL,
  `tags` varchar(5000) NOT NULL,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_target`
--

CREATE TABLE IF NOT EXISTS `razor_target` (
  `tid` int(11) NOT NULL,
  `userid` int(11) NOT NULL,
  `productid` int(11) NOT NULL,
  `targetname` varchar(128) NOT NULL,
  `targettype` int(11) DEFAULT NULL,
  `unitprice` decimal(12,2) NOT NULL,
  `targetstatusc` int(11) NOT NULL DEFAULT '1',
  `createdate` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_targetevent`
--

CREATE TABLE IF NOT EXISTS `razor_targetevent` (
  `teid` int(11) NOT NULL,
  `targetid` int(11) NOT NULL,
  `eventid` int(11) NOT NULL,
  `eventalias` varchar(128) NOT NULL,
  `sequence` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_user2product`
--

CREATE TABLE IF NOT EXISTS `razor_user2product` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `product_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_user2role`
--

CREATE TABLE IF NOT EXISTS `razor_user2role` (
  `id` int(11) NOT NULL,
  `userid` int(11) NOT NULL,
  `roleid` int(11) NOT NULL DEFAULT '1'
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_user2role`
--

INSERT INTO `razor_user2role` (`id`, `userid`, `roleid`) VALUES
(1, 1, 3);

-- --------------------------------------------------------

--
-- 表的结构 `razor_userkeys`
--

CREATE TABLE IF NOT EXISTS `razor_userkeys` (
  `id` int(20) NOT NULL,
  `user_id` int(20) NOT NULL,
  `user_key` varchar(50) NOT NULL,
  `user_secret` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_users`
--

CREATE TABLE IF NOT EXISTS `razor_users` (
  `id` int(11) NOT NULL,
  `username` varchar(50) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `password` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `email` varchar(100) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `activated` tinyint(1) NOT NULL DEFAULT '1',
  `banned` tinyint(1) NOT NULL DEFAULT '0',
  `ban_reason` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `new_password_key` varchar(50) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `new_password_requested` datetime DEFAULT NULL,
  `new_email` varchar(100) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `new_email_key` varchar(50) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `last_ip` varchar(40) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `last_login` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `created` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `sessionkey` varchar(50) DEFAULT NULL
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_users`
--

INSERT INTO `razor_users` (`id`, `username`, `password`, `email`, `activated`, `banned`, `ban_reason`, `new_password_key`, `new_password_requested`, `new_email`, `new_email_key`, `last_ip`, `last_login`, `created`, `modified`, `sessionkey`) VALUES
(1, 'admin', 'e10adc3949ba59abbe56e057f20f883e', 'qinghai.zhang@wbkit.com', 1, 0, NULL, NULL, NULL, NULL, NULL, '0.0.0.0', '2017-07-25 17:24:51', '2017-07-25 17:23:03', '2017-07-25 09:24:51', NULL);

-- --------------------------------------------------------

--
-- 表的结构 `razor_user_autologin`
--

CREATE TABLE IF NOT EXISTS `razor_user_autologin` (
  `key_id` char(32) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `user_id` int(11) NOT NULL DEFAULT '0',
  `user_agent` varchar(150) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `last_ip` varchar(40) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL,
  `last_login` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- 表的结构 `razor_user_permissions`
--

CREATE TABLE IF NOT EXISTS `razor_user_permissions` (
  `id` int(11) NOT NULL,
  `role` int(11) DEFAULT NULL,
  `resource` int(11) DEFAULT NULL,
  `read` tinyint(1) DEFAULT '0',
  `write` tinyint(1) DEFAULT '0',
  `modify` tinyint(1) DEFAULT '0',
  `delete` tinyint(1) DEFAULT '0',
  `publish` tinyint(1) DEFAULT '0',
  `description` varchar(255) DEFAULT NULL
) ENGINE=InnoDB AUTO_INCREMENT=85 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_user_permissions`
--

INSERT INTO `razor_user_permissions` (`id`, `role`, `resource`, `read`, `write`, `modify`, `delete`, `publish`, `description`) VALUES
(1, 1, 1, 1, 1, 0, 0, 0, NULL),
(2, 2, 1, 0, 0, 0, 0, 0, NULL),
(3, 3, 1, 1, 1, 1, 1, 1, NULL),
(4, 1, 2, 0, 0, 0, 0, 0, NULL),
(5, 2, 2, 0, 0, 0, 0, 0, NULL),
(6, 3, 2, 1, 1, 1, 1, 1, NULL),
(7, 1, 3, 0, 0, 0, 0, 0, NULL),
(8, 2, 3, 0, 0, 0, 0, 0, NULL),
(9, 3, 3, 1, 0, 0, 0, 0, NULL),
(10, 1, 4, 0, 0, 0, 0, 0, NULL),
(11, 2, 4, 0, 0, 0, 0, 0, NULL),
(12, 3, 4, 1, 0, 0, 0, 0, NULL),
(13, 1, 5, 0, 0, 0, 0, 0, NULL),
(14, 2, 5, 0, 0, 0, 0, 0, NULL),
(15, 3, 5, 1, 0, 0, 0, 0, NULL),
(16, 1, 6, 0, 0, 0, 0, 0, NULL),
(17, 2, 6, 0, 0, 0, 0, 0, NULL),
(18, 3, 6, 1, 0, 0, 0, 0, NULL),
(19, 1, 7, 0, 0, 0, 0, 0, NULL),
(20, 2, 7, 0, 0, 0, 0, 0, NULL),
(21, 3, 7, 1, 0, 0, 0, 0, NULL),
(22, 1, 8, 0, 0, 0, 0, 0, NULL),
(23, 2, 8, 0, 0, 0, 0, 0, NULL),
(24, 3, 8, 1, 0, 0, 0, 0, NULL),
(25, 1, 9, 0, 0, 0, 0, 0, NULL),
(26, 2, 9, 0, 0, 0, 0, 0, NULL),
(27, 3, 9, 1, 0, 0, 0, 0, NULL),
(28, 1, 10, 0, 0, 0, 0, 0, NULL),
(29, 2, 10, 0, 0, 0, 0, 0, NULL),
(30, 3, 10, 1, 0, 0, 0, 0, NULL),
(31, 1, 11, 0, 0, 0, 0, 0, NULL),
(32, 2, 11, 0, 0, 0, 0, 0, NULL),
(33, 3, 11, 1, 0, 0, 0, 0, NULL),
(34, 1, 12, 0, 0, 0, 0, 0, NULL),
(35, 2, 12, 0, 0, 0, 0, 0, NULL),
(36, 3, 12, 1, 0, 0, 0, 0, NULL),
(37, 1, 13, 0, 0, 0, 0, 0, NULL),
(38, 2, 13, 0, 0, 0, 0, 0, NULL),
(39, 3, 13, 1, 0, 0, 0, 0, NULL),
(40, 1, 14, 0, 0, 0, 0, 0, NULL),
(41, 2, 14, 0, 0, 0, 0, 0, NULL),
(42, 3, 14, 1, 0, 0, 0, 0, NULL),
(43, 1, 15, 0, 0, 0, 0, 0, NULL),
(44, 2, 15, 0, 0, 0, 0, 0, NULL),
(45, 3, 15, 1, 0, 0, 0, 0, NULL),
(46, 1, 16, 0, 0, 0, 0, 0, NULL),
(47, 2, 16, 0, 0, 0, 0, 0, NULL),
(48, 3, 16, 1, 0, 0, 0, 0, NULL),
(49, 1, 17, 0, 0, 0, 0, 0, NULL),
(50, 2, 17, 0, 0, 0, 0, 0, NULL),
(51, 3, 17, 1, 0, 0, 0, 0, NULL),
(52, 1, 18, 0, 0, 0, 0, 0, NULL),
(53, 2, 18, 0, 0, 0, 0, 0, NULL),
(54, 3, 18, 1, 0, 0, 0, 0, NULL),
(55, 1, 19, 0, 0, 0, 0, 0, NULL),
(56, 2, 19, 0, 0, 0, 0, 0, NULL),
(57, 3, 19, 1, 0, 0, 0, 0, NULL),
(58, 1, 20, 0, 0, 0, 0, 0, NULL),
(59, 2, 20, 0, 0, 0, 0, 0, NULL),
(60, 3, 20, 1, 0, 0, 0, 0, NULL),
(61, 1, 21, 0, 0, 0, 0, 0, NULL),
(62, 2, 21, 0, 0, 0, 0, 0, NULL),
(63, 3, 21, 1, 0, 0, 0, 0, NULL),
(64, 1, 22, 0, 0, 0, 0, 0, NULL),
(65, 2, 22, 0, 0, 0, 0, 0, NULL),
(66, 3, 22, 1, 0, 0, 0, 0, NULL),
(67, 1, 23, 0, 0, 0, 0, 0, NULL),
(68, 2, 23, 0, 0, 0, 0, 0, NULL),
(69, 3, 23, 1, 0, 0, 0, 0, NULL),
(70, 1, 24, 0, 0, 0, 0, 0, NULL),
(71, 2, 24, 0, 0, 0, 0, 0, NULL),
(72, 3, 24, 1, 0, 0, 0, 0, NULL),
(73, 1, 25, 0, 0, 0, 0, 0, NULL),
(74, 2, 25, 0, 0, 0, 0, 0, NULL),
(75, 3, 25, 1, 0, 0, 0, 0, NULL),
(76, 1, 26, 0, 0, 0, 0, 0, NULL),
(77, 2, 26, 0, 0, 0, 0, 0, NULL),
(78, 3, 26, 1, 0, 0, 0, 0, NULL),
(79, 1, 27, 0, 0, 0, 0, 0, NULL),
(80, 2, 27, 0, 0, 0, 0, 0, NULL),
(81, 3, 27, 1, 0, 0, 0, 0, NULL),
(82, 1, 28, 0, 0, 0, 0, 0, NULL),
(83, 2, 28, 0, 0, 0, 0, 0, NULL),
(84, 3, 28, 1, 0, 0, 0, 0, NULL);

-- --------------------------------------------------------

--
-- 表的结构 `razor_user_profiles`
--

CREATE TABLE IF NOT EXISTS `razor_user_profiles` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `country` varchar(20) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `website` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `companyname` varchar(100) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `contact` varchar(100) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `telephone` varchar(50) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `QQ` varchar(20) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `MSN` varchar(30) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `Gtalk` varchar(30) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_user_profiles`
--

INSERT INTO `razor_user_profiles` (`id`, `user_id`, `country`, `website`, `companyname`, `contact`, `telephone`, `QQ`, `MSN`, `Gtalk`) VALUES
(1, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- 表的结构 `razor_user_resources`
--

CREATE TABLE IF NOT EXISTS `razor_user_resources` (
  `id` int(11) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `description` varchar(255) DEFAULT NULL,
  `parentId` int(11) DEFAULT NULL
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_user_resources`
--

INSERT INTO `razor_user_resources` (`id`, `name`, `description`, `parentId`) VALUES
(1, 'test', 'Acl Test Controller', NULL),
(2, 'User', '用户管理', NULL),
(3, 'Product', '我的应用', NULL),
(4, 'errorlogondevice', '错误设备统计', NULL),
(5, 'productbasic', '基本统计', NULL),
(6, 'Auth', '用户', NULL),
(7, 'Autoupdate', '自动更新', NULL),
(8, 'Channel', '渠道', NULL),
(9, 'Device', '设备', NULL),
(10, 'Event', '事件管理', NULL),
(11, 'Onlineconfig', '发送策略', NULL),
(12, 'Operator', '运营商', NULL),
(13, 'Os', '操作系统统计', NULL),
(14, 'Profile', '个人资料', NULL),
(15, 'Resolution', '分辨率统计', NULL),
(16, 'Usefrequency', '使用频率统计', NULL),
(17, 'Usetime', '使用时长统计', NULL),
(18, 'errorlog', '错误日志', NULL),
(19, 'Eventlist', '事件', NULL),
(20, 'market', '渠道STATISTICS', NULL),
(21, 'region', '地域统计', NULL),
(22, 'errorlogonos', '错误操作系统统计', NULL),
(23, 'version', '版本统计', NULL),
(24, 'console', '应用', NULL),
(25, 'Userremain', '用户留存', NULL),
(26, 'Pagevisit', '页面访问统计', NULL),
(27, 'Network', '联网方式统计', NULL),
(28, 'funnels', '漏斗模型', NULL);

-- --------------------------------------------------------

--
-- 表的结构 `razor_user_roles`
--

CREATE TABLE IF NOT EXISTS `razor_user_roles` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `parentId` int(11) DEFAULT NULL
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8;

--
-- 转存表中的数据 `razor_user_roles`
--

INSERT INTO `razor_user_roles` (`id`, `name`, `description`, `parentId`) VALUES
(1, 'user', 'normal user', NULL),
(2, 'guest', 'not log in', NULL),
(3, 'admin', 'system admin', NULL);

-- --------------------------------------------------------

--
-- 表的结构 `razor_wifi_towers`
--

CREATE TABLE IF NOT EXISTS `razor_wifi_towers` (
  `id` int(50) NOT NULL,
  `clientdataid` int(50) NOT NULL,
  `mac_address` varchar(50) NOT NULL,
  `signal_strength` varchar(50) NOT NULL,
  `age` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `razor_alert`
--
ALTER TABLE `razor_alert`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_alertdetail`
--
ALTER TABLE `razor_alertdetail`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_cell_towers`
--
ALTER TABLE `razor_cell_towers`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_channel`
--
ALTER TABLE `razor_channel`
  ADD PRIMARY KEY (`channel_id`);

--
-- Indexes for table `razor_channel_product`
--
ALTER TABLE `razor_channel_product`
  ADD PRIMARY KEY (`cp_id`);

--
-- Indexes for table `razor_ci_sessions`
--
ALTER TABLE `razor_ci_sessions`
  ADD PRIMARY KEY (`session_id`);

--
-- Indexes for table `razor_clientdata`
--
ALTER TABLE `razor_clientdata`
  ADD PRIMARY KEY (`id`),
  ADD KEY `insertdate` (`insertdate`);

--
-- Indexes for table `razor_clientusinglog`
--
ALTER TABLE `razor_clientusinglog`
  ADD PRIMARY KEY (`id`),
  ADD KEY `insertdate` (`insertdate`);

--
-- Indexes for table `razor_config`
--
ALTER TABLE `razor_config`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_device_tag`
--
ALTER TABLE `razor_device_tag`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_errorlog`
--
ALTER TABLE `razor_errorlog`
  ADD PRIMARY KEY (`id`),
  ADD KEY `insertdate` (`insertdate`);

--
-- Indexes for table `razor_eventdata`
--
ALTER TABLE `razor_eventdata`
  ADD PRIMARY KEY (`id`),
  ADD KEY `insertdate` (`insertdate`);

--
-- Indexes for table `razor_event_defination`
--
ALTER TABLE `razor_event_defination`
  ADD PRIMARY KEY (`event_id`),
  ADD UNIQUE KEY `channel_id` (`channel_id`,`product_id`,`user_id`,`event_name`);

--
-- Indexes for table `razor_getui_product`
--
ALTER TABLE `razor_getui_product`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `id` (`id`);

--
-- Indexes for table `razor_login_attempts`
--
ALTER TABLE `razor_login_attempts`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_markevent`
--
ALTER TABLE `razor_markevent`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_platform`
--
ALTER TABLE `razor_platform`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_plugins`
--
ALTER TABLE `razor_plugins`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_product`
--
ALTER TABLE `razor_product`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_productfiles`
--
ALTER TABLE `razor_productfiles`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_product_category`
--
ALTER TABLE `razor_product_category`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_product_version`
--
ALTER TABLE `razor_product_version`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_reportlayout`
--
ALTER TABLE `razor_reportlayout`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_tag_group`
--
ALTER TABLE `razor_tag_group`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_target`
--
ALTER TABLE `razor_target`
  ADD PRIMARY KEY (`tid`);

--
-- Indexes for table `razor_targetevent`
--
ALTER TABLE `razor_targetevent`
  ADD PRIMARY KEY (`teid`);

--
-- Indexes for table `razor_user2product`
--
ALTER TABLE `razor_user2product`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_user2role`
--
ALTER TABLE `razor_user2role`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_userkeys`
--
ALTER TABLE `razor_userkeys`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_users`
--
ALTER TABLE `razor_users`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_user_autologin`
--
ALTER TABLE `razor_user_autologin`
  ADD PRIMARY KEY (`key_id`,`user_id`);

--
-- Indexes for table `razor_user_permissions`
--
ALTER TABLE `razor_user_permissions`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_user_profiles`
--
ALTER TABLE `razor_user_profiles`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_user_resources`
--
ALTER TABLE `razor_user_resources`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_user_roles`
--
ALTER TABLE `razor_user_roles`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `razor_wifi_towers`
--
ALTER TABLE `razor_wifi_towers`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `razor_alert`
--
ALTER TABLE `razor_alert`
  MODIFY `id` int(50) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_alertdetail`
--
ALTER TABLE `razor_alertdetail`
  MODIFY `id` int(50) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_cell_towers`
--
ALTER TABLE `razor_cell_towers`
  MODIFY `id` int(10) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_channel`
--
ALTER TABLE `razor_channel`
  MODIFY `channel_id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=7;
--
-- AUTO_INCREMENT for table `razor_channel_product`
--
ALTER TABLE `razor_channel_product`
  MODIFY `cp_id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_clientdata`
--
ALTER TABLE `razor_clientdata`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_clientusinglog`
--
ALTER TABLE `razor_clientusinglog`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_config`
--
ALTER TABLE `razor_config`
  MODIFY `id` int(50) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_device_tag`
--
ALTER TABLE `razor_device_tag`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_errorlog`
--
ALTER TABLE `razor_errorlog`
  MODIFY `id` int(50) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_eventdata`
--
ALTER TABLE `razor_eventdata`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_event_defination`
--
ALTER TABLE `razor_event_defination`
  MODIFY `event_id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_getui_product`
--
ALTER TABLE `razor_getui_product`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_login_attempts`
--
ALTER TABLE `razor_login_attempts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_markevent`
--
ALTER TABLE `razor_markevent`
  MODIFY `id` int(50) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_platform`
--
ALTER TABLE `razor_platform`
  MODIFY `id` int(50) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=4;
--
-- AUTO_INCREMENT for table `razor_plugins`
--
ALTER TABLE `razor_plugins`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_product`
--
ALTER TABLE `razor_product`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_productfiles`
--
ALTER TABLE `razor_productfiles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_product_category`
--
ALTER TABLE `razor_product_category`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=34;
--
-- AUTO_INCREMENT for table `razor_product_version`
--
ALTER TABLE `razor_product_version`
  MODIFY `id` int(50) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_reportlayout`
--
ALTER TABLE `razor_reportlayout`
  MODIFY `id` int(50) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_tag_group`
--
ALTER TABLE `razor_tag_group`
  MODIFY `id` int(4) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_target`
--
ALTER TABLE `razor_target`
  MODIFY `tid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_targetevent`
--
ALTER TABLE `razor_targetevent`
  MODIFY `teid` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_user2product`
--
ALTER TABLE `razor_user2product`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_user2role`
--
ALTER TABLE `razor_user2role`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=2;
--
-- AUTO_INCREMENT for table `razor_userkeys`
--
ALTER TABLE `razor_userkeys`
  MODIFY `id` int(20) NOT NULL AUTO_INCREMENT;
--
-- AUTO_INCREMENT for table `razor_users`
--
ALTER TABLE `razor_users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=2;
--
-- AUTO_INCREMENT for table `razor_user_permissions`
--
ALTER TABLE `razor_user_permissions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=85;
--
-- AUTO_INCREMENT for table `razor_user_profiles`
--
ALTER TABLE `razor_user_profiles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=2;
--
-- AUTO_INCREMENT for table `razor_user_resources`
--
ALTER TABLE `razor_user_resources`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=29;
--
-- AUTO_INCREMENT for table `razor_user_roles`
--
ALTER TABLE `razor_user_roles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT,AUTO_INCREMENT=4;
--
-- AUTO_INCREMENT for table `razor_wifi_towers`
--
ALTER TABLE `razor_wifi_towers`
  MODIFY `id` int(50) NOT NULL AUTO_INCREMENT;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
