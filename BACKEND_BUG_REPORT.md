# Backend Bug Report: Multiple Orders Created for Single Order Request

## Issue Description
When placing an order with multiple items from the Flutter app, the backend creates **separate orders** (with different order IDs) instead of **one order with multiple items**.

## Expected Behavior
- User adds 3 items to cart
- User places order
- Backend creates **1 order** with order ID (e.g., ORD-251209-00001)
- This order contains **3 line items**
- User sees **1 order** in their order list

## Actual Behavior
- User adds 3 items to cart
- User places order
- Backend creates **3 separate orders** with different order IDs:
  - ORD-251209-00001 (Item 1)
  - ORD-251209-00002 (Item 2)
  - ORD-251209-00003 (Item 3)
- User sees **3 orders** in their order list

## Technical Details

### Flutter App (Correct)
The Flutter app makes **ONE API call** to `place_order` endpoint with the following data structure:

```
POST https://webdevelopercg.com/janaushadhi/myadmin/UserApis/place_order

Data sent:
{
  "M1_CODE": "299",
  "F4_PARTY": "299",
  "F4_BT": "Placed",
  "M1_ADD_ID": "300",
  "F4_F1[0]": "114",           // Product 1 ID
  "F4_QTOT[0]": "4",           // Product 1 Quantity
  "F4_AMT1[0]": "140.00",      // Product 1 MRP
  "F4_AMT2[0]": "130.00",      // Product 1 Sale Price
  "F4_AMT3[0]": "560.00",      // Product 1 Total MRP
  "F4_AMT4[0]": "520.00",      // Product 1 Total Sale
  "F4_F1[1]": "273",           // Product 2 ID
  "F4_QTOT[1]": "2",           // Product 2 Quantity
  "F4_AMT1[1]": "200.00",      // Product 2 MRP
  "F4_AMT2[1]": "180.00",      // Product 2 Sale Price
  "F4_AMT3[1]": "400.00",      // Product 2 Total MRP
  "F4_AMT4[1]": "360.00",      // Product 2 Total Sale
  "F4_STOT": "880.00",         // Subtotal
  "F4_DAMT": "0",              // Delivery Amount
  "F4_DIS": "0",               // Discount
  "F4_GTOT": "880.00",         // Grand Total
  "payment_method": "COD",
  "payment_status": "pending"
}
```

### Backend API (Bug)
The backend `place_order` API is:
1. ✅ Receiving the request correctly
2. ❌ Creating separate orders for each item instead of one order with multiple items
3. ❌ Returning multiple order IDs instead of one

## Required Backend Fix

The backend API should:

1. **Parse all items from the request**
   ```php
   // Loop through all F4_F1[0], F4_F1[1], F4_F1[2], etc.
   $items = [];
   $index = 0;
   while (isset($_POST["F4_F1[$index]"])) {
       $items[] = [
           'product_id' => $_POST["F4_F1[$index]"],
           'quantity' => $_POST["F4_QTOT[$index]"],
           'mrp' => $_POST["F4_AMT1[$index]"],
           'sale_price' => $_POST["F4_AMT2[$index]"],
           'total_mrp' => $_POST["F4_AMT3[$index]"],
           'total_sale' => $_POST["F4_AMT4[$index]"]
       ];
       $index++;
   }
   ```

2. **Create ONE order header**
   ```sql
   INSERT INTO orders (F4_NO, F4_PARTY, F4_BT, F4_ADD1, F4_STOT, F4_GTOT, ...)
   VALUES ('ORD-251209-00001', '299', 'Placed', '300', '880.00', '880.00', ...)
   ```

3. **Create multiple order line items for that ONE order**
   ```sql
   INSERT INTO order_items (F4_NO, F4_F1, F4_QTOT, F4_AMT1, F4_AMT2, ...)
   VALUES 
     ('ORD-251209-00001', '114', '4', '140.00', '130.00', ...),
     ('ORD-251209-00001', '273', '2', '200.00', '180.00', ...)
   ```

4. **Return ONE order ID**
   ```json
   {
     "response": "success",
     "message": "Order placed successfully",
     "F4_NO": "ORD-251209-00001"
   }
   ```

## Impact
- Users are confused seeing multiple orders when they placed one
- Order management becomes difficult
- Inventory tracking is incorrect
- Payment reconciliation is problematic

## Priority
**HIGH** - This affects every multi-item order

## Verification
After fixing, test by:
1. Adding 3 different products to cart
2. Placing order
3. Verify only 1 order ID is created
4. Verify that order contains all 3 items
5. Check order_details API returns all items for that order ID
