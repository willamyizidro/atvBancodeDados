--1 - Crie uma função para reajustar salários. O reajuste deve ser aplicado para todos os funcionários, e deve seguir a seguinte tabela:

create or replace function ajustarsalario()
returns boolean as
$$
begin
update funcionarios
set salario = salario * 1.05
where funcionarios.id in (select f.id 
from funcionarios f 
left join (select count(d.id) as quantidade , d.id
	from atividadesprojetos atvp
	join projetos p on p.id = atvp.projeto_id
	join departamentos d on p.departamento_id = d.id
	group by d.id)as teste on f.departamento_id = teste.id
	where teste.quantidade is null);
	
update funcionarios
set salario = salario * 1.10
where funcionarios.id in (select f.id 
from funcionarios f 
left join (select count(d.id) as quantidade , d.id
	from atividadesprojetos atvp
	join projetos p on p.id = atvp.projeto_id
	join departamentos d on p.departamento_id = d.id
	group by d.id)as teste on f.departamento_id = teste.id
	where teste.quantidade > 0 and teste.quantidade <= 2 );
	
update funcionarios
set salario = salario * 1.15
where funcionarios.id in (select f.id 
from funcionarios f 
left join (select count(d.id) as quantidade , d.id
	from atividadesprojetos atvp
	join projetos p on p.id = atvp.projeto_id
	join departamentos d on p.departamento_id = d.id
	group by d.id)as teste on f.departamento_id = teste.id
	where teste.quantidade >= 3 );
return True;	
end;
$$
language plpgsql


--2 - Execute o reajuste criado na questão 1:

select ajustarsalario()



--3 - Modifique a tabela Departamentos, acrescentando uma coluna chamada total_atividades (numeric). Essa coluna deve ser preenchida para todos os departamentos, contendo o número de atividades desenvolvidas, somando todos os projetos daquele departamento específico.


alter table departamentos
add column total_atividades int

update departamentos
set total_atividades  =  teste.quantidade
from (select count(d.id) as quantidade , d.id as id
	from atividadesprojetos atvp
	join projetos p on p.id = atvp.projeto_id
	join departamentos d on p.departamento_id = d.id
	group by d.id) as teste 
where departamentos.id = teste.id

select *
from departamentos


--4 - Crie um gatilho na tabela AtividadesProjetos, para que cada vez que uma nova linha seja inserida a tabela Departamentos tenha o seu campo total_atividades ajustado no departamento responsável pelo projeto no qual foi realizada uma nova atividade.

create or replace function atualiza_total_atividades()
returns trigger as
$$
declare id_dep int;
begin 
select d.id
	from departamentos d
	join projetos p on p.departamento_id = d.id
	where new.projeto_id = p.id into id_dep;
	
if id_dep is null then	
raise exception 'departamento nao encontrado.';

else
update departamentos
set total_atividades = total_atividades + 1
where departamentos.id = id_dep;
end if;
return new;
end;
$$
language plpgsql

create trigger gatilho_atualiza_total_atividades
after insert on atividadesprojetos
for each row 
execute function atualiza_total_atividades()


--5 - Crie uma tabela chamada Prêmios (id, funcionario_id, data, valor).

create table premios(
	id int primary key,
	funcionario_id integer,
	date date,
	valor numeric,
	foreign key (funcionario_id) references funcionarios(id) on delete cascade
)

--6 - Crie um gatilho na tabela AtividadesProjetos, para que cada vez que uma nova linha seja inserida, caso o funcionário responsável pelo projeto tenha atingido 3 atividades, receba um prêmio de 20% do salário (inserido na tabela prêmio).

drop function insere_premio;
create or replace function insere_premio()
returns trigger as 
$$
declare 
id_func int;
total_att int;
begin

select count(atvp.projeto_id)
from atividadesprojetos atvp
join projetos p on atvp.projeto_id = p.id
where new.projeto_id = p.id
group by atvp.projeto_id into total_att;

select d.funcionario_gerente_id
from departamentos d
join projetos p on p.departamento_id = d.id
where p.id = new.projeto_id into id_func;

if total_att >= 3 then
	insert into premios
	values ((select count(*)
		   from premios)+1, id_func, null, 
			(select salario
		   	from funcionarios
		   	where id = id_func)*0.2);
return new;			
end if;
end;
$$
language plpgsql

create trigger gatilho_insere_premio
after insert on atividadesprojetos
for each row
execute function insere_premio()


--7 - Crie uma visão chamada Total_premios_2023, que contenha o nome do funcionário e o total em prêmios que ele tem a receber em 2023.

create view total_premios_2023 as
select f.nome as nome , sum(p.valor) as totalPremios
from premios p 
join funcionarios f on p.funcionario_id = f.id
where  extract(year from p.date ) = '2023'
group by f.nome


select *
from Total_premios_2023