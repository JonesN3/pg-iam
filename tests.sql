
-- TODOs:
-- test capability generation and validation
-- audit tests
-- rpc API + tests
-- consistent trigger names, code cleanup
-- docs

create or replace function test_persons_users_groups()
    returns boolean as $$
    declare pid uuid;
    declare num int;
    begin
        insert into persons (given_names, surname, person_expiry_date)
            values ('Sarah', 'Conner', '2020-10-01');
        select person_id from persons where surname = 'Conner' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-sconne', '2020-03-28');
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p66-sconne', '2019-12-01');
        -- creation
        assert (select count(*) from persons) = 1, 'person creation issue';
        assert (select count(*) from users) = 2, 'user creation issue';
        assert (select count(*) from groups) = 3, 'group creation issue';
        -- person attribute immutability
        begin
            update persons set row_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'row_id immutable';
        end;
        begin
            update persons set person_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'person_id immutable';
        end;
        begin
            update persons set person_group = 'e14c538a-4b8b-4393-9fb2-056e363899e1-group';
            assert false;
        exception when others then
            raise notice 'person_group immutable';
        end;
        -- user attribute immutability
        begin
            update users set row_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'row_id immutable';
        end;
        begin
            update users set user_id = 'a3981c7f-8e41-4222-9183-1815b6ec9c3b';
            assert false;
        exception when others then
            raise notice 'user_id immutable';
        end;
        begin
            update users set user_name = 'p11-scnr';
            assert false;
        exception when others then
            raise notice 'user_name immutable';
        end;
        begin
            update users set user_group = 'p11-s-group';
            assert false;
        exception when others then
            raise notice 'user_group immutable';
        end;
        -- group attribute immutability
        begin
            update groups set row_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'row_id immutable';
        end;
        begin
            update groups set group_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'group_id immutable';
        end;
        begin
            update groups set group_name = 'p22-lcd-group';
            assert false;
        exception when others then
            raise notice 'group_name immutable';
        end;
        begin
            update groups set group_class = 'secondary';
            assert false;
        exception when others then
            raise notice 'group_class immutable';
        end;
        begin
            update groups set group_type = 'person';
            assert false;
        exception when others then
            raise notice 'group_type immutable';
        end;
        -- states; cascades, constraints
        update persons set person_activated = 'f';
        assert (select count(*) from users where user_activated = 't') = 0,
            'person state changes not propagating to users';
        assert (select count(*) from groups where group_activated = 't') = 0,
            'person state changes not propagating to groups';
        -- try change group states, expect fail
        -- create secondary group, change state, delete it again
        -- expiry dates: cascades, constraints
        update persons set person_expiry_date = '2019-09-09';
        update users set user_expiry_date = '2000-08-08' where user_name like 'p11-%';
        begin
            update groups set group_expiry_date = '2000-01-01' where group_primary_member = 'p11-sconne';
            assert false;
        exception when others then
            raise notice 'primary group updates';
        end;
        -- deletion; cascades, constraints
        begin
            delete from groups where group_type = 'person';
        exception when others then
            raise notice 'person group deletion protected';
        end;
        begin
            delete from groups where group_type = 'user';
        exception when others then
            raise notice 'user group deletion protected';
        end;
        begin
            delete from groups where group_class = 'primary';
        exception when others then
            raise notice 'primary group deletion protected';
        end;
        delete from persons;
        assert (select count(*) from users) = 0, 'cascading delete from person to users not working';
        assert (select count(*) from groups) = 0, 'cascading delete from person to groups not working';
    return true;
    end;
$$ language plpgsql;


create or replace function test_group_memeberships_moderators()
    returns boolean as $$
    declare pid uuid;
    declare row record;
    begin
        -- create persons and users
        insert into persons (given_names, surname, person_expiry_date)
            values ('Sarah', 'Conner', '2020-10-01');
        select person_id from persons where surname = 'Conner' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-sconne', '2020-03-28');
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p66-sconne', '2019-12-01');
        insert into persons (given_names, surname, person_expiry_date)
            values ('John', 'Conner2', '2020-10-01');
        select person_id from persons where surname = 'Conner2' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-jconn', '2020-03-28');
        insert into persons (given_names, surname, person_expiry_date)
            values ('Frank', 'Castle', '2020-10-01');
        select person_id from persons where surname = 'Castle' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-fcl', '2020-03-28');
        insert into persons (given_names, surname, person_expiry_date)
            values ('Virginia', 'Woolf', '2020-10-01');
        select person_id from persons where surname = 'Woolf' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-vwf', '2020-03-28');
        insert into persons (given_names, surname, person_expiry_date)
            values ('David', 'Gilgamesh', '2020-10-01');
        select person_id from persons where surname = 'Gilgamesh' into pid;
        insert into users (person_id, user_name, user_expiry_date)
            values (pid, 'p11-dgmsh', '2020-03-28');
        -- create groups
        insert into groups (group_name, group_class, group_type)
            values ('p11-admin-group', 'secondary', 'generic');
        insert into groups (group_name, group_class, group_type)
            values ('p11-export-group', 'secondary', 'generic');
        insert into groups (group_name, group_class, group_type)
            values ('p11-publication-group', 'secondary', 'generic');
        insert into groups (group_name, group_class, group_type)
            values ('p11-clinical-group', 'secondary', 'generic');
        insert into groups (group_name, group_class, group_type)
            values ('p11-import-group', 'secondary', 'generic');
        insert into groups (group_name, group_class, group_type)
            values ('p11-special-group', 'secondary', 'generic');
        -- add members
        insert into group_memberships (group_name, group_member_name)
            values ('p11-export-group', 'p11-admin-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-export-group', 'p11-sconne-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-export-group', 'p11-jconn-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-export-group', 'p11-clinical-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-admin-group', 'p11-fcl-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-publication-group', 'p11-vwf-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-admin-group', 'p11-publication-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-clinical-group', 'p11-dgmsh-group');
        insert into group_memberships (group_name, group_member_name)
            values ('p11-special-group', 'p11-import-group');
        /*
        This gives a valid group membership graph as follows:

            p11-export-group
                -> p11-sconne-group
                -> p11-jconn-group
                -> p11-clinical-group
                    -> p11-dgmsh-group
                -> p11-admin-group
                    -> p11-fcl-group
                    -> p11-publication-group
                        -> p11-vwf-group

        We should be able to resolve such DAGs, of arbitrary depth
        until we can report back the list of all group_primary_member(s).
        And optionally, the structure of the graph. In this case the list is:

            p11-sconne
            p11-jconn
            p11-dgmsh
            p11-fcl
            p11-vwf

        */
        raise notice 'group_name, group_member_name, group_class, group_type, group_primary_member';
        for row in select * from first_order_members loop
            raise notice '%', row;
        end loop;


        /* GROUP MEMBERS */

        -- referential constraints
        begin
            insert into group_moderators (group_name, group_member_name)
                values ('p77-clinical-group', 'p11-special-group');
            assert false;
        exception when others then
            raise notice 'group_memberships: referential constraints work';
        end;
        -- redundancy
        begin
            insert into group_memberships (group_name, group_member_name) values ('p11-export-group','p11-publication-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_memberships: redundancy check works';
        end;
        -- cyclicality
        begin
            insert into group_memberships (group_name, group_member_name) values ('p11-publication-group','p11-export-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_memberships: cyclicality check works';
        end;
        -- immutability
        begin
            update group_memberships set row_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'group_memberships: row_id immutable';
        end;
        begin
            update group_memberships set group_name = 'p11-clinical-group' where group_name = 'p11-special-group';
            assert false;
        exception when others then
            raise notice 'group_memberships: group_name immutable';
        end;
        begin
            update group_memberships set group_member_name = 'p11-clinical-group' where group_name = 'p11-special-group';
            assert false;
        exception when others then
            raise notice 'group_memberships: group_member_name immutable';
        end;
        -- group classes
        begin
            insert into group_memberships values ('p11-sconne-group', 'p11-special-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_memberships: primary groups cannot have new members';
        end;
        -- new relations and group activation state
        begin
            update groups set group_activated = 'f' where group_name = 'p11-import-group';
            insert into group_memberships (group_name, group_member_name) values ('p11-publication-group','p11-import-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_memberships: deactivated groups cannot be used in new relations';
        end;
        -- new relations and group expiry
        begin
            update groups set group_expiry_date = '2017-01-01' where group_name = 'p11-import-group';
            insert into group_memberships (group_name, group_member_name) values ('p11-publication-group','p11-import-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_memberships: expired groups cannot be used in new relations';
        end;
        -- shouldnt be able to be a member of itself
        begin
            insert into group_moderators (group_name, group_member_name)
                values ('p11-special-group', 'p11-special-group');
            assert false;
        exception when others then
            raise notice 'group_memberships: redundancy check - groups cannot be members of themselves';
        end;

        /* GROUP MODERATORS */

        insert into group_moderators (group_name, group_moderator_name)
            values ('p11-import-group', 'p11-admin-group');
        insert into group_moderators (group_name, group_moderator_name)
            values ('p11-clinical-group', 'p11-special-group');
        -- referential constraints
        begin
            insert into group_moderators (group_name, group_moderator_name)
                values ('p77-clinical-group', 'p11-special-group');
            assert false;
        exception when others then
            raise notice 'group_moderators: referential constraints work';
        end;
        -- immutability
        begin
            update group_moderators set row_id = 'e14c538a-4b8b-4393-9fb2-056e363899e1';
            assert false;
        exception when others then
            raise notice 'group_moderators: row_id immutable';
        end;
        begin
            update group_moderators set group_name = 'p11-admin-group' where group_name = 'p11-import-group';
            assert false;
        exception when others then
            raise notice 'group_moderators: group_name immutable';
        end;
        begin
            update group_moderators set group_member_name = 'p11-export-group' where group_name = 'p11-import-group';
            assert false;
        exception when others then
            raise notice 'group_moderators: group_member_name immutable';
        end;
        -- redundancy
        begin
            insert into group_moderators (group_name, group_moderator_name)
                values ('p11-clinical-group', 'p11-special-group');
            assert false;
        exception when others then
            raise notice 'group_moderators: redundancy check works - cannot recreate existing relations';
        end;
        begin
            insert into group_moderators (group_name, group_moderator_name)
                values ('p11-clinical-group', 'p11-clinical-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_moderators: redundancy check works - groups cannot moderate themselves';
        end;
        -- cyclicality
        begin
            insert into group_moderators (group_name, group_moderator_name)
                values ('p11-special-group', 'p11-clinical-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_moderators: cyclicality check works';
        end;
        -- new relations and group activation state
        begin
            update groups set group_activated = 'f' where group_name = 'p11-export-group';
            insert into group_moderators (group_name, group_moderator_name)
                values ('p11-export-group', 'p11-admin-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_moderators: deactivated groups cannot be used';
        end;
        -- new relations and group expiry
        begin
            update groups set group_expiry_date = '2011-01-01' where group_name = 'p11-export-group';
            insert into group_moderators (group_name, group_moderator_name)
                values ('p11-export-group', 'p11-admin-group');
            assert false;
        exception when assert_failure then
            raise notice 'group_moderators: expired groups cannot be used';
        end;
        update groups set group_expiry_date = '2011-01-01' where group_name = 'p11-export-group';
        --delete from persons;
        --delete from groups;
        return true;
    end;
$$ language plpgsql;


create or replace function test_capabilities()
    returns boolean as $$
    begin
        insert into capabilities (capability_type, capability_default_claims,
                                  capability_required_groups, capability_group_match_method,
                                  capability_lifetime, capability_description, capability_expiry_date)
            values ('p11import', '{"role": "p11_import_user"}',
                    '{"p11-export-group", "p11-special-group"}', 'exact',
                    '123', 'bla', current_date);
        insert into capabilities (capability_type, capability_default_claims,
                                  capability_required_groups, capability_group_match_method,
                                  capability_lifetime, capability_description, capability_expiry_date)
            values ('export', '{"role": "export_user"}',
                    '{"admin-group", "export-group"}', 'wildcard',
                    '123', 'bla', current_date);
        insert into capabilities (capability_type, capability_default_claims,
                                  capability_required_groups, capability_group_match_method,
                                  capability_lifetime, capability_description, capability_expiry_date)
            values ('admin', '{"role": "admin_user"}',
                    '{"admin-group", "special-group"}', 'wildcard',
                    '123', 'bla', current_date);
        -- immutability
        -- uniqueness
        -- referential constraints

        -- specify capabilities authorization: sets of operations on sets of resources
        -- example entries
        -- id, import, PUT, /(.*)/files/stream
        -- id, import, PUT, /(.*)/files/upload
        -- id, import, GET, /(.*)/files/resumables
        -- id, export, DELETE, /(.*)/files/export/(.*)
        return true;
    end;
$$ language plpgsql;


create or replace function test_audit()
    returns boolean as $$
    begin
        -- for each table check it works
        return true;
    end;
$$ language plpgsql;


create or replace function test_rpcs()
    returns boolean as $$
    begin
        -- person_groups
        -- person_capabilities
        return true;
    end;
$$ language plpgsql;


delete from persons;
delete from groups;
delete from audit_log;
delete from capabilities;
select test_persons_users_groups();
select test_group_memeberships_moderators();
select test_capabilities();
select test_audit();
select test_rpcs();
