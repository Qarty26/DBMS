--########################################################################
--ex6#####################################################################
--########################################################################
create or replace procedure ex6 as

    type tabel_index is table of number index by pls_integer;
    type tabel_echipe is table of varchar2(100);
    type array_ture is varray(100) of number;
    
    etape tabel_index;
    echipe tabel_echipe := tabel_echipe();
    ture array_ture := array_ture();
    v_ture number;

    cursor iduri is
        SELECT id_etapa
        FROM etapa
        WHERE mod(id_etapa,2) = 1;
        
    
begin
    for etapa in iduri loop
        etape(etape.count + 1) := etapa.id_etapa;
    end loop;
    
    for i in 1..etape.count loop
        for ec in 
            (select nume_echipa
            from echipa e, participa p
            where e.id_echipa = p.id_echipa
            and p.id_etapa = etape(i)
            and p.nr_piloti >= 0) 
            loop
                echipe.extend;
                echipe(echipe.last) := ec.nume_echipa;
            end loop;
            
        for nr_ture in
            (select numar_total_ture
            from cursa
            where id_etapa = etape(i))
            loop
                ture.extend;
                ture(ture.last) := nr_ture.numar_total_ture;
            end loop;
            
            
        if echipe.count > 0 then
            DBMS_output.put('La etapa ' || etape(i) || ' au participat echipele: ');
            for i in 1..echipe.count loop
                DBMS_output.put(echipe(i) || ' - ');
            end loop;
            
            v_ture := 0;
            for i in 1..ture.count loop
                v_ture := v_ture + ture(i);
            end loop;
            dbms_output.put_line('si au parcurs ' || v_ture || ' ture de circuit');
        end if;
        ture.delete;
        echipe.delete;
                 
    end loop;
end;
/

execute ex6;

--########################################################################
--ex7#####################################################################
--########################################################################

CREATE OR REPLACE PROCEDURE ex7 AS
    
    TYPE refcursor is ref cursor;
    angajati refcursor;
    v_culoare echipa.main_color%TYPE := 'yellow';
    v_echipa echipa.nume_echipa%TYPE;
    v_staff staff.nume_staff%type; 

    CURSOR ec(culoare VARCHAR2) IS
        SELECT e.nume_echipa,
               CURSOR (
                   SELECT s.nume_staff
                   FROM staff s
                   WHERE s.id_echipa = e.id_echipa
               )
        FROM echipa e
        WHERE e.main_color = culoare;
BEGIN
    OPEN ec(v_culoare);
    LOOP
        FETCH ec into v_echipa,angajati;
        EXIT WHEN ec%NOTFOUND;

        DBMS_OUTPUT.PUT('Echipa ' || v_echipa || ' este formata din: ');
        
        LOOP
            fetch angajati into v_staff;
            exit when angajati%notfound;
            DBMS_OUTPUT.PUT(v_staff || ' ');
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('');
    END LOOP;
    close ec;
END;
/

execute ex7;

--########################################################################
--ex8#####################################################################
--########################################################################


create or replace function ex8 return varchar2 is

    type tabel_nr_piloti is table of varchar2(100);
    wrong_date exception;
    bad_register exception;
    
    nr_piloti tabel_nr_piloti := tabel_nr_piloti();
    v_echipa echipa.id_echipa%type;
    v_etapa etapa.id_etapa%type;
    data_inc etapa.data_inceput%type;
    data_fin etapa.data_final%type;
    nr_p number;
    
    cursor ec is
        select id_echipa,count(p.id_pilot)
        from pilot p, staff s, kart k
        where p.id_staff = s.id_staff
        and k.numar_kart = p.numar_kart
        and k.main_kart = 1
        group by id_echipa
        order by 1; 
        
    cursor et is
        select id_etapa, data_inceput, data_final
        from etapa;
    
begin

    for i in (select id_echipa from echipa) loop
        nr_piloti.extend;
    end loop;
    
    open ec;
    loop
        fetch ec into v_echipa, nr_p;
        exit when ec%notfound;
        nr_piloti(v_echipa) := nr_p;
    end loop;
    close ec;
  
    open et;
    loop
        fetch et into v_etapa, data_inc, data_fin;
        exit when et%notfound;
        if data_inc > data_fin then
            raise wrong_date;
        end if;
    end loop;
    close et;
    
    for round in (select id_etapa from etapa) loop
        for i in 1..nr_piloti.count loop
            select nr_piloti
            into nr_p
            from participa
            where id_etapa = round.id_etapa
            and id_echipa = i;
                
            if nr_p > nr_piloti(i) then
                raise bad_register;
            end if;
        end loop;
    end loop;

    return 'da';
    
exception
    
    when wrong_date then
        return 'no, invalid date';
    when bad_register then
        return 'no, bad team register';

end ex8;
/

select ex8 from dual;

--########################################################################
--ex9#####################################################################
--########################################################################

create or replace procedure ex9 as

      TYPE t_result IS RECORD (
        id_campionat NUMBER,
        tbuget NUMBER,
        cost_total NUMBER,
        profit NUMBER
      );
      
      TYPE t_matrix IS TABLE OF t_result;
      v_results t_matrix;
      
      nr_campionate number;
      NO_DATA_FOUND exception;
      TOO_MANY_ROWS exception;
      
    cursor profitCampionat is
    select bu.id_campionat,tbuget,cost_total,tbuget-cost_total as profit
    from (select s.id_campionat,sum(s.suma)+ k.buget as tbuget
            from sponsorizeaza s, campionat_karting k
            where k.id_campionat = s.id_campionat
            group by s.id_campionat,k.buget) bu,
            
            (select id_campionat,sum(cost_etapa) as cost_total
            from (select e.id_campionat,e.id_etapa,tcost-tnrp as cost_etapa 
                from etapa e,(select id_circuit, 5 * lungime * latime_max as tcost 
                                from circuit) c,(select id_etapa, 400*sum(nr_piloti) as tnrp
                                                from participa
                                                group by id_etapa) p
            where e.id_circuit = c.id_circuit
            and p.id_etapa = e.id_etapa)
            group by id_campionat) co
            
    where co.id_campionat = bu.id_campionat
    order by 1;
    
begin

    select count(*)
    into nr_campionate
    from campionat_karting;

    OPEN profitCampionat;
    FETCH profitCampionat BULK COLLECT INTO v_results;
    CLOSE profitCampionat;

    IF v_results.COUNT = 0 THEN
        raise no_data_found;
    elsif v_results.count > nr_campionate then
        raise too_many_rows;
    else
    FOR i IN v_results.FIRST .. v_results.LAST LOOP
        DBMS_OUTPUT.PUT_LINE(
          'ID_CAMPIONAT: ' || v_results(i).id_campionat ||
          ' | TOTAL_BUGET: ' || v_results(i).tbuget ||
          ' | COST_TOTAL: ' || v_results(i).cost_total ||
          ' | PROFIT: ' || v_results(i).profit
        );
  END LOOP;
  end if;
  
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Nu s-au gãsit date.');
  WHEN TOO_MANY_ROWS THEN
    DBMS_OUTPUT.PUT_LINE('Prea multe înregistrãri gãsite.');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('O eroare a apãrut: ' || SQLERRM);
END ex9;
/


begin
    ex9;
end;
/

--########################################################################
--ex10####################################################################
--########################################################################


create or replace trigger limita_categorie
before insert on pilot

FOR EACH ROW

declare
    v_nr number;
    v_categorie varchar2(100);
begin

    v_categorie := TRIM(LOWER(:new.categorie));
    
    select count(*)
    into v_nr
    from pilot
    where trim(lower(categorie)) = v_categorie;

    if v_nr + 1 > 3 then
         RAISE_APPLICATION_ERROR(-20001, 'Nu se permite inserarea a mai mult de 3 piloti la aceeasi cagtegorie');
    end if;
end limita_categorie;
/

--########################################################################
--ex11####################################################################
--########################################################################

create or replace trigger limita_categorie
before insert on pilot
for each row
declare
    v_nr number;
    v_categorie varchar2(100);
begin
    v_categorie := TRIM(LOWER(:new.categorie));
    select count(*)
    into v_nr
    from pilot
    where trim(lower(categorie)) = v_categorie;

    if v_nr >= 3 then
         RAISE_APPLICATION_ERROR(-20001, 'Nu se permite inserarea a mai mult de 3 piloti la aceeasi cagtegorie');
    end if;
end limita_categorie;
/

--########################################################################
--ex12####################################################################
--########################################################################


CREATE OR REPLACE TRIGGER safety
BEFORE DROP OR ALTER ON DATABASE
DECLARE
BEGIN
   DBMS_OUTPUT.PUT_LINE('Triggerul de securitate este activat. Dezactiva-ti-l pentru a realiza operatiile dorite!');
   RAISE_APPLICATION_ERROR(-20001, 'Trigger safety activ');
END safety;
/

alter trigger safety enable;
alter trigger safety disable;
drop table pilot;


--########################################################################
--ex13####################################################################
--########################################################################


create or replace package pachet_karting as

    --ex6
    procedure ex6;
    --ex7
    procedure ex7;
    --ex8
    function ex8 return varchar2;
    --ex9
    procedure ex9;
    
end pachet_karting;


--#################################################
create or replace package body pachet_karting as

    ----------------------------------------------------------------------------------------------------------------
    --ex6-----------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------------------
    procedure ex6 as

    type tabel_index is table of number index by pls_integer;
    type tabel_echipe is table of varchar2(100);
    type array_ture is varray(100) of number;
    
    etape tabel_index;
    echipe tabel_echipe := tabel_echipe();
    ture array_ture := array_ture();
    v_ture number;

    cursor iduri is
        SELECT id_etapa
        FROM etapa
        WHERE mod(id_etapa,2) = 1;
        
    begin
        for etapa in iduri loop
            etape(etape.count + 1) := etapa.id_etapa;
        end loop;
        
        for i in 1..etape.count loop
            for ec in 
                (select nume_echipa
                from echipa e, participa p
                where e.id_echipa = p.id_echipa
                and p.id_etapa = etape(i)
                and p.nr_piloti >= 0) 
                loop
                    echipe.extend;
                    echipe(echipe.last) := ec.nume_echipa;
                end loop;
                
            for nr_ture in
                (select numar_total_ture
                from cursa
                where id_etapa = etape(i))
                loop
                    ture.extend;
                    ture(ture.last) := nr_ture.numar_total_ture;
                end loop;
                
            if echipe.count > 0 then
                DBMS_output.put('La etapa ' || etape(i) || ' au participat echipele: ');
                for i in 1..echipe.count loop
                    DBMS_output.put(echipe(i) || ' - ');
                end loop;
                
                v_ture := 0;
                for i in 1..ture.count loop
                    v_ture := v_ture + ture(i);
                end loop;
                dbms_output.put_line('si au parcurs ' || v_ture || ' ture de circuit');
            end if;
            ture.delete;
            echipe.delete;
                     
        end loop;
    end ex6;
    
    ----------------------------------------------------------------------------------------------------------------
    --Ex7-----------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------------------
    
    PROCEDURE ex7 AS
    
    TYPE refcursor is ref cursor;
    angajati refcursor;
    v_culoare echipa.main_color%TYPE := 'yellow';
    v_echipa echipa.nume_echipa%TYPE;
    v_staff staff.nume_staff%type; 

    CURSOR ec(culoare VARCHAR2) IS
        SELECT e.nume_echipa,
               CURSOR (
                   SELECT s.nume_staff
                   FROM staff s
                   WHERE s.id_echipa = e.id_echipa
               )
        FROM echipa e
        WHERE e.main_color = culoare;
    BEGIN
        OPEN ec(v_culoare);
        LOOP
            FETCH ec into v_echipa,angajati;
            EXIT WHEN ec%NOTFOUND;
    
            DBMS_OUTPUT.PUT('Echipa ' || v_echipa || ' este formata din: ');
            
            LOOP
                fetch angajati into v_staff;
                exit when angajati%notfound;
                DBMS_OUTPUT.PUT(v_staff || ' ');
            END LOOP;
            
            DBMS_OUTPUT.PUT_LINE('');
        END LOOP;
        CLOSE ec;
    END ex7;
    
    ----------------------------------------------------------------------------------------------------------------
    --ex8-----------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------------------
    
    function ex8 return varchar2 is

    type tabel_nr_piloti is table of varchar2(100);
    wrong_date exception;
    bad_register exception;
    
    nr_piloti tabel_nr_piloti := tabel_nr_piloti();
    v_echipa echipa.id_echipa%type;
    v_etapa etapa.id_etapa%type;
    data_inc etapa.data_inceput%type;
    data_fin etapa.data_final%type;
    nr_p number;
    
    cursor ec is
        select id_echipa,count(p.id_pilot)
        from pilot p, staff s, kart k
        where p.id_staff = s.id_staff
        and k.numar_kart = p.numar_kart
        and k.main_kart = 1
        group by id_echipa
        order by 1; 
        
    cursor et is
        select id_etapa, data_inceput, data_final
        from etapa;
    
    begin
    
    for i in (select id_echipa from echipa) loop
        nr_piloti.extend;
    end loop;
    
    open ec;
    loop
        fetch ec into v_echipa, nr_p;
        exit when ec%notfound;
        nr_piloti(v_echipa) := nr_p;
    end loop;
    close ec;
  
    open et;
    loop
        fetch et into v_etapa, data_inc, data_fin;
        exit when et%notfound;
        if data_inc > data_fin then
            raise wrong_date;
        end if;
    end loop;
    close et;
    
    for round in (select id_etapa from etapa) loop
        for i in 1..nr_piloti.count loop
            select nr_piloti
            into nr_p
            from participa
            where id_etapa = round.id_etapa
            and id_echipa = i;
                
            if nr_p > nr_piloti(i) then
                raise bad_register;
            end if;
        end loop;
    end loop;

    return 'da';
    
    exception
        when wrong_date then
            return 'no, invalid date';
        when bad_register then
            return 'no, bad team register';
    
    end ex8;
    
    ----------------------------------------------------------------------------------------------------------------
    --ex9-----------------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------------------
    procedure ex9 as

      TYPE t_result IS RECORD (
        id_campionat NUMBER,
        tbuget NUMBER,
        cost_total NUMBER,
        profit NUMBER
      );
      
      TYPE t_matrix IS TABLE OF t_result;
      v_results t_matrix;
      
      nr_campionate number;
      NO_DATA_FOUND exception;
      TOO_MANY_ROWS exception;
      
    cursor profitCampionat is
    select bu.id_campionat,tbuget,cost_total,tbuget-cost_total as profit
    from (select s.id_campionat,sum(s.suma)+ k.buget as tbuget
            from sponsorizeaza s, campionat_karting k
            where k.id_campionat = s.id_campionat
            group by s.id_campionat,k.buget) bu,
            
            (select id_campionat,sum(cost_etapa) as cost_total
            from (select e.id_campionat,e.id_etapa,tcost-tnrp as cost_etapa 
                from etapa e,(select id_circuit, 5 * lungime * latime_max as tcost 
                                from circuit) c,(select id_etapa, 400*sum(nr_piloti) as tnrp
                                                from participa
                                                group by id_etapa) p
            where e.id_circuit = c.id_circuit
            and p.id_etapa = e.id_etapa)
            group by id_campionat) co
            
    where co.id_campionat = bu.id_campionat
    order by 1;
    
    begin
    
        select count(*)
        into nr_campionate
        from campionat_karting;
    
        OPEN profitCampionat;
        FETCH profitCampionat BULK COLLECT INTO v_results;
        CLOSE profitCampionat;
    
        IF v_results.COUNT = 0 THEN
            raise no_data_found;
        elsif v_results.count > nr_campionate then
            raise too_many_rows;
        else
        FOR i IN v_results.FIRST .. v_results.LAST LOOP
            DBMS_OUTPUT.PUT_LINE(
              'ID_CAMPIONAT: ' || v_results(i).id_campionat ||
              ' | TOTAL_BUGET: ' || v_results(i).tbuget ||
              ' | COST_TOTAL: ' || v_results(i).cost_total ||
              ' | PROFIT: ' || v_results(i).profit
            );
      END LOOP;
      end if;
      
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Nu s-au gãsit date.');
      WHEN TOO_MANY_ROWS THEN
        DBMS_OUTPUT.PUT_LINE('Prea multe înregistrãri gãsite.');
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('O eroare a apãrut: ' || SQLERRM);
    END ex9;   
    
end pachet_karting;
