CREATE DATABASE ex_triggers_07
GO
USE ex_triggers_07
GO
CREATE TABLE cliente (
codigo INT NOT NULL,
nome VARCHAR(70) NOT NULL
PRIMARY KEY(codigo)
)
GO
CREATE TABLE venda (
codigo_venda INT NOT NULL,
codigo_cliente INT NOT NULL,
valor_total DECIMAL(7,2) NOT NULL
PRIMARY KEY (codigo_venda)
FOREIGN KEY (codigo_cliente) REFERENCES cliente(codigo)
)
GO
CREATE TABLE pontos (
codigo_cliente INT NOT NULL,
total_pontos DECIMAL(4,1) NOT NULL
PRIMARY KEY (codigo_cliente)
FOREIGN KEY (codigo_cliente) REFERENCES cliente(codigo)
)

Create Trigger t_altVenda on venda
Instead of update
as
Begin
	Declare @cod_venda int
	set @cod_venda = (Select Top(1) codigo_venda from venda order by codigo_venda desc)
	Select c.nome, v.valor_total from venda v, cliente c where v.codigo_venda = @cod_venda 		
End

GO
--Segunda Trigger
Create Trigger t_pontos on venda
after Insert
as
Begin
	Declare @valor_venda decimal(7,2),
			@pontos decimal(4,1),
			@cod_cliente int, 
			@cons_cliente int

	set @valor_venda = (Select valor_total from inserted)
	set @pontos = @valor_venda * 0.1
	set @cod_cliente = (Select codigo_cliente from inserted)
	set @cons_cliente = (Select codigo_cliente from pontos where codigo_cliente = @cod_cliente)

	If(@cons_cliente is null) Begin
		Insert Into pontos Values
		(@cod_cliente, @pontos) 
	End
	Else Begin
		Update pontos set total_pontos = total_pontos + @pontos where codigo_cliente = @cod_cliente
	End

	set @pontos = (Select total_pontos from pontos where codigo_cliente = @cod_cliente)
	If(@pontos >= 1) Begin
		print 'O cliente atingiu ' + Cast(@pontos as varchar(10)) + ' pontos'
		Update pontos set total_pontos = total_pontos - 1 where codigo_cliente = @cod_cliente
		set @pontos = @pontos - 1
		print 'O cliente esta atualmente com ' + Cast(@pontos as varchar(10)) + ' pontos'
		
	End
End

INSERT INTO cliente (codigo, nome) VALUES (1, 'João Silva');

INSERT INTO venda (codigo_venda, codigo_cliente, valor_total) VALUES (1, 1, 100.00);

-- Exercicio 2
GO
CREATE TABLE Produto (
    codigo INT PRIMARY KEY,
    nome VARCHAR(100),
    descricao VARCHAR(255),
    valor_unitario DECIMAL(7, 2)
);
Go
CREATE TABLE Estoque (
codigo_produto INT,
qtd_estoque INT,
estoque_minimo INT,
PRIMARY KEY (codigo_produto)
)	
Go
CREATE TABLE Venda_2 (
nota_fiscal INT PRIMARY KEY,
codigo_produto INT REFERENCES Produto(codigo),
quantidade INT
);
Go
Create Trigger t_vendaEstoque on Venda_2
after insert
as
begin
	declare @cod_produto int,
			@qtd_venda int,
			@qtd_estoque int,
			@nota int

	set @cod_produto = (select codigo_produto from inserted)
	set @qtd_estoque = (select qtd_estoque from Estoque where codigo_produto = @cod_produto)
	set @qtd_venda = (select quantidade from inserted)
	if(@qtd_venda > @qtd_estoque) begin
		RollBack Transaction 
		RAISERROR('Essa quantidade de produto não está disponivel no estoque', 16, 1)
	End
	Else Begin
		if(@qtd_estoque>(Select estoque_minimo from Estoque where codigo_produto = @cod_produto))Begin
			print 'Estoque abaixo do minimo'
		End
	set @nota = (select nota_fiscal from inserted)
	select * from fn_geraNota(@nota)
	End
end

-- Função gera nota
Go
Create FUNCTION fn_geraNota(@nota int)
RETURNS @tabela TABLE (
nota_fiscal		INT,
codigo_produto		Int,
nome_produto		varchar(100),
descricao		varchar(100),
valor_unitario			DECIMAL(7,2),
quantidade	int,
valor_total			DECIMAL(7,2)
)
BEGIN
	declare @valor_total decimal(7,2)

	set @valor_total = (Select p.valor_unitario from Produto p, Venda_2 v where v.nota_fiscal = @nota and p.codigo = v.codigo_produto)
	set @valor_total = @valor_total * (Select quantidade from Venda_2 where nota_fiscal = @nota)

	Insert into @tabela 
	Select v.nota_fiscal, v.codigo_produto, p.nome, p.descricao, p.valor_unitario, v.quantidade, @valor_total as valor_total
	from Produto p, Venda_2 v 
	where v.nota_fiscal = @nota 
		  and v.codigo_produto = p.codigo
	return
END

-- Testes
INSERT INTO Produto (codigo, nome, descricao, valor_unitario)
VALUES (1, 'Camiseta', 'Camiseta de algodão branca', 29.99);

Go
INSERT INTO Estoque (codigo_produto, qtd_estoque, estoque_minimo)
VALUES (1, 50, 10);

go
INSERT INTO Venda_2(nota_fiscal, codigo_produto, quantidade)
VALUES (1001, 1, 3);