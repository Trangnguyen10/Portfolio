Create Database GlobalSuperStore;

Use GlobalSuperStore;

Select * 
From Raw_Orders
--Create Orders Table
Select distinct Order_ID Order_code,
	   Order_Date,
	   Ship_Date,
	   Ship_Mode Ship_mode,
	   Order_Priority Order_priority
Into Orders
From Raw_Orders

--- Check unique Order_code--
Select *
from Orders
Where Order_code in  
(
Select Order_code
from Orders
Group by Order_code
having Count(ship_mode) > 1
)
order by Order_code

---Order_code not unique ( same code but different Order_Date and Ship_Date). It should be made unique in Raw_Order

Update Raw_Orders
Set Order_ID = CONCAT(Order_ID, 
			  convert(varchar, Order_Date, 35),
			  convert(varchar, Ship_Date, 35))
-- Update Orders table
Delete Orders
Insert Into Orders
Select distinct Order_ID,
	   Order_Date,
	   Ship_Date,
	   Ship_Mode,
	   Order_Priority
From Raw_Orders


--- Check Unique Order Code ---
Select count(*), count(distinct order_code)
From Orders
--- Add index column--

Alter Table Orders Add OrderID int identity (1,1);

Select * 
From Orders

--Create Locations Table
Select Distinct City,
				State,
				Country,
				Postal_Code PostaL_code,
				Market,
				Region
Into Locations
From Raw_Orders


-- Check Unique
Select count(*),
	   count(distinct city)
from Locations

Select *
from Locations 
Where City in
(
	Select City
	From Locations
	Group By City
	Having count(Postal_code) > 1
)		--- Unique when City + Postal_code

-- Add index column to Customers
Alter Table Locations Add LocationID int identity(1,1)

Select *
From Locations

Update Locations 
Set Postal_code = Isnull(Postal_code, 0)


--Create Customers Table
Select distinct Customer_ID Customer_code,
	   Customer_Name Customer_name,
	   Segment Customer_type
Into Customers
From Raw_Orders

--Check Unique
Select count(*),
	   count(distinct Customer_code)
From Customers
		
-- Add index column to Customers
Alter Table Customers Add CustomerID int identity (1,1);

Select *
From Customers

--- Add Location ID to Orders

With cte As
(
	Select distinct Order_ID,
			City,
			State,
			Country,
			Market,
			Region,
			isnull(Postal_code,0) Postal_code
	From Raw_Orders
),
b as
(
	Select distinct a.*, 
					b.LocationID
	From cte a left join Locations b on (a.City = b.City and 
										a.State = b.State and
										a.country = b.country and
										a.Market = b.Market and
										a.Region = b.Region and
										a.postal_code = b.Postal_code)
)
Select a.*,
		b.LocationID
into Temp_Orders
from b b right join Orders a on a.Order_code = b.Order_ID

Drop table Orders
Exec sp_rename 'Temp_Orders', 'Orders'


---Create table Product

Select distinct Product_ID Product_code,
				Category,
				Sub_Category Sub_category,
				Product_Name Product_name
into Products
From Raw_Orders

---Check Unique

Select * 
from Products
Where Product_code in 
(
	Select Product_code
	From Products
	Group by Product_code
	Having count(product_name)>1
)
Order By Product_code

---Same Product_code different Product_Name
--- Update Product_code from Raw_Orders


Select *,
		DENSE_RANK() over(Partition by Product_ID Order By Product_name) ranks
Into temp_raws
From Raw_Orders
Select *
from temp_raws

Update temp_raws
set Product_ID = Product_ID + convert(varchar(1),ranks)

Alter table temp_raws
drop column ranks

Drop table Raw_Orders

Exec sp_rename 'temp_raws', 'Raw_Orders'
					

--- Update table Products 
Delete Products

Insert Into Products
Select distinct Product_ID,
				Category,
				Sub_Category,
				Product_Name
From Raw_Orders

--- add index column ProductID

Alter table Products add ProductID int identity(1,1)

Select *
From Products

--- Create Table OrderItems
Select *
From Raw_Orders

With temp1 As
(
	Select a.Order_ID Order_code,
		   a.Product_ID Product_code,
		   a.Customer_ID Customer_code,
		   a.Sales Sales_price,
		   a.Quantity,
		   a.Discount,
		   a.Profit,
		   a.Shipping_Cost Shipping_cost,
		   isnull(b.Returned,1) Returned
	From Raw_Orders a 
				left join Returns b on (substring(a.Order_ID, 1, len(a.Order_ID)-20) = b.Order_ID and
										a.Market = b.Market)
),
temp2 As
(	
	Select b.OrderID,
		   c.ProductID,
		   d.CustomerID,
		   a.Sales_price,
		   a.Quantity,
		   a.Discount,
		   a.Profit,
		   a.Shipping_cost,
		   Case when a.Returned ='Yes' then 0
				else 1
				End 'Returned'
	from temp1 a
			left join Orders b on a.Order_code = b.Order_code
			left join Products c on a.product_code = c.Product_code
			left join Customers d on a.Customer_code = d.Customer_code
)
Select * 
into OrderItems
from temp2

--- Add index ItemID into OrderItems

Alter Table OrderItems Add ItemId int identity(1,1)

Alter Table OrderItems
	Alter Column Returned int

-- Create primary key/ Forign Key
Alter Table Locations
	Add Constraint Locations_LocationID Primary Key Clustered (LocationID);

Alter Table Orders
	Add Constraint Orders_OrderID Primary Key Clustered (OrderID),
	    Constraint Orders_LocationID Foreign Key (LocationID)
		References Locations (LocationID)
		On Delete Cascade;

Alter Table Customers
	Add Constraint Customers_CustomerID Primary Key Clustered (CustomerID);

Alter Table Products
	Add Constraint Products_ProductID Primary Key Clustered (ProductID);

Alter Table OrderItems
	Add Constraint OrderItems_ItemID Primary Key clustered (ItemID),
	    Constraint OrderItems_OrderID Foreign Key (OrderID)
			References Orders (OrderID)
			On Delete Cascade,
		Constraint OrderItems_ProductID Foreign Key (ProductID)
			References Products (ProductID)
			On Delete Cascade,
		Constraint OrderItems_CustomerID Foreign Key (CustomerID)
			References Customers (CustomerID)
			On Delete Cascade;