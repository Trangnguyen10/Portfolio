Use BikeStore;

Select *
From production.brands;

Select *
From production.categories;

Select *
From production.products;

Select *
From production.stocks;

Select *
From sales.customers;

Select *
From sales.order_items;

Select *
From sales.orders;

Select *
From sales.staffs;

Select *
From sales.stores;


--Create procedure to daily update table

Create procedure updatetable 
	(@tablename varchar(500),
	 @date varchar(25))
	as
	begin 
	DECLARE @file_name varchar(500)
	DECLARE @sql varchar(8000)
	SET @file_name = 'F:\Data Analysis\Dataset\BikeStore\' + @tablename + @date +'.csv'
	SET @sql = '
	BULK INSERT '+@tablename +' 
	FROM "'+ @file_name + '"
	WITH
	(
	FIRSTROW = 2,
	FIELDTERMINATOR = '','',
	ROWTERMINATOR = ''\n''
	)'

	EXEC(@sql)
end

--- Update table production.stocks by latest data calling from today---
Declare @today varchar(500) = CONVERT(NVARCHAR(20),getdate(),112)
Delete from production.stocks
Exec updatetable 
	@tablename='production.stocks',
	@date =@today

--- top 10 customers with highest order value

With total_by_order as(

	Select order_id, 
		   sum((quantity*list_price)*(1-discount))  total_by_order
	From sales.order_items
	Group by Order_id
),

total_table As (
	Select b.customer_id, 
		   c.first_name, 
		   c.last_name, 
		   sum(a.total_by_order) as total,
		   row_number() over (order by sum(a.total_by_order) desc) ranks
	From total_by_order a left join sales.orders b
			on a.order_id = b.order_id
						left join sales.customers c
			on b.customer_id = c.customer_id
	Group by b.customer_id, c.first_name, c.last_name
)

Select *
From total_table
Where ranks <=10

---Top 2 store with higest revenue considering store the same revenue 
Create View Ordervalue as
(
	Select order_id, 
		   sum((quantity*list_price)*(1-discount))  total_by_order
	From sales.order_items
	Group by Order_id
);
with storeresult as
(
	Select b.store_id,
		   c.store_name,
		   c.city,
		   Sum(a.total_by_order) RevenueByStore,
		   rank() over ( order by  Sum(a.total_by_order) desc) ranks
	From Ordervalue a 
				left join sales.orders b on a.order_id =b.order_id
				left join sales.stores c on b.store_id = c.store_id
	Group by b.store_id,
			 c.store_name,
		     c.city
)
Select *
from storeresult
where ranks <= 2
---top 10 best-seller of the year 2017, provide ranking for each product
With BestSeller As 
(
	Select a.product_id, 
		   c.product_name,
		   Sum(a.quantity) as salenumber, 
		   rank() over (order by Sum(a.quantity) desc) ranks
	From sales.order_items a 
			inner join sales.orders b on a.order_id = b.order_id
			inner join production.products c on a.product_id = c.product_id
	Where year(b.order_date) =2017
	Group by a.product_id, c.product_name
)
Select *
from BestSeller
where ranks <=10 
order by ranks;


---Revenue by month
Select format(b.order_date, 'yyyyMM') Periods,
		sum(total_by_order) total	
from Ordervalue a
		left join sales.orders b on a.order_id = b.order_id
Group by format(b.order_date, 'yyyyMM')
Order by format(b.order_date, 'yyyyMM')

---Revenue by product in the year of 2016

Select c.product_id,
	   c.product_name,
	   Sum((a.quantity*a.list_price)*(1-a.discount)) as ProductRevenue
From sales.order_items a 
			left join sales.orders b on a.order_id = b.order_id
			right join production.products c on a.product_id = c.product_id
Where year(b.order_date) = 2016
Group by c.product_id, c.product_name
order by c.product_id

---Revenue by brands

Select a.brand_id,
	   a.brand_name,
	   format(d.order_date, 'yyyy') year,
	   Sum((c.quantity*c.list_price)*(1-c.discount)) as BrandRevenue
From production.brands a 
			left join production.products b on a.brand_id = b.brand_id
			left join sales.order_items c on b.product_id = c.product_id
			left join sales.orders d on c.order_id = d.order_id
Group by a.brand_id,
		 a.brand_name,
	     format(d.order_date, 'yyyy') 
having format(d.order_date, 'yyyy') is not null
order by a.brand_id, format(d.order_date, 'yyyy')


---Print list of item having revenue excess 40,000
Create View RevenueByProduct as
(
	Select product_id,
		   sum((quantity*list_price)*(1-discount)) total_by_item
	From sales.order_items
	Group by product_id
)

select a.product_id,
	   b.product_name
from RevenueByProduct a 
		left join production.products b on a.product_id = b.product_id
where a.total_by_item >40000

---Print list of item available over 60 units in stock
Select a.product_id,
	   b.product_name,
	   sum(a.quantity) total_quantity
From production.stocks a
		left join production.products b on a.product_id = b.product_id
Group by a.product_id,
	     b.product_name
Having sum(a.quantity) > 60
Order by  total_quantity asc

---Within 10 customers with higest order value, find the one placing largest order numbers. 
With CustomerOrder As
(
Select c.customer_id,
	   c.first_name,
	   c.last_name,
	   rank() over (order by sum(a.total_by_order) desc) RankByRevenue,
	   count(b.order_id) number_of_orders
from Ordervalue a 
		left join sales.orders b on a.order_id = b.order_id
		right join sales.customers c on b.customer_id = c.customer_id
group by c.customer_id,
	     c.first_name,
	     c.last_name
)
Select top 1 *
From CustomerOrder
where RankByRevenue < 10 
order by number_of_orders desc

---Caculate the total numbers of each product sold in 12/2017
Select a.product_id,
	   c.product_name,
	   format(b.order_date,'MMyyyy') Month,
	   sum((a.quantity*a.list_price)*(1-a.discount)) ProductRevenue
From sales.order_items a 
		left join sales.orders b on a.order_id = b.order_id
		left join production.products c on a.product_id = c.product_id
group by a.product_id,
		 c.product_name,
	     format(b.order_date,'MMyyyy')
having format(b.order_date,'MMyyyy') = '122017'

---Find 2 best selling products of each categories
With RankByCategories As
(
Select c.category_id,
	   c.category_name,
	   b.product_id,
	   b.product_name,
	   sum((a.quantity*a.list_price)*(1-a.discount)) ProductRevenue,
	   Dense_rank() over( partition  by c.category_id
						  order by sum((a.quantity*a.list_price)*(1-a.discount)) desc) ranks
From sales.order_items a 
			right join production.products b on a.product_id = b.product_id
			right join production.categories c on b.category_id = c.category_id
Group by c.category_id,
	     c.category_name,
	     b.product_id,
		 b.product_name
)
Select *
From RankByCategories
Where ranks <=2

---Write function to caculate the final price of product after discount
Create Function F_FinalPrice
	(@productid int)
Returns nvarchar(max)
As
Begin
Declare @result nvarchar(max)
Declare @price float 
Set @price =
	(
	Select AvgPrice
	From
	(
		Select product_id,
				sum((quantity*list_price)*(1-discount))/sum(quantity) AvgPrice
		From sales.order_items
		Group by product_id
		Having product_id = @productid
	) sub
	)
Set @result =  'The Final Price of product with id = ' 
				 + convert(nvarchar(20),@productid) 
				 + ' is '
				 + convert(nvarchar(20), @price)
Return @result
End

Print dbo.F_FinalPrice(12)
Go
