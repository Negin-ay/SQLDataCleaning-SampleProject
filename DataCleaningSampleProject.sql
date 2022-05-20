-- 1) Rows with NULL PropertyAddress
SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress
FROM Houses.data_cleaning a
JOIN Houses.data_cleaning b
	ON a.ParcelID = b.ParcelID
	AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress IS NULL;

-- 2) Populating PropertyAddress
SET SQL_SAFE_UPDATES = 0;
UPDATE Houses.data_cleaning a
INNER JOIN Houses.data_cleaning b
	on a.ParcelID = b.ParcelID
	AND a.UniqueID <> b.UniqueID
    SET a.PropertyAddress=b.PropertyAddress
WHERE a.PropertyAddress IS NULL;

-- 3) Breaking out Address into different columns (city, state, etc.)
SELECT
substring(PropertyAddress, 1, LOCATE(',', PropertyAddress) -1 ) AS Address
, substring(PropertyAddress, LOCATE(',', PropertyAddress) + 1 ) AS City
FROM Houses.data_cleaning;
ALTER TABLE Houses.data_cleaning
ADD PropertySplitAddress NVARCHAR(255);
UPDATE Houses.data_cleaning
SET PropertySplitAddress = substring(PropertyAddress, 1, LOCATE(',', PropertyAddress) -1 );
ALTER TABLE Houses.data_cleaning
ADD PropertySplitCity NVARCHAR(255);
UPDATE Houses.data_cleaning
SET PropertySplitCity = substring(PropertyAddress, LOCATE(',', PropertyAddress) + 1 );

-- 4) Simpler alternative for lines 23 to 26
SELECT 
substring_index(OwnerAddress, ',' , 1),
substring_index(substring_index(OwnerAddress, ',' , 2), ',' , -1),
substring_index(substring_index(OwnerAddress, ',' , 3), ',' , -1)
FROM Houses.data_cleaning;

-- 5) Change Y and N to Yes and No in "Sold as Vacant" field
SELECT Distinct(SoldAsVacant), COUNT(SoldAsVacant)
FROM Houses.data_cleaning
GROUP BY SoldAsVacant
ORDER BY 2;
SELECT SoldAsVacant,
CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	   WHEN SoldAsVacant = 'N' THEN 'No'
	   ELSE SoldAsVacant
	   END
From Houses.data_cleaning;
UPDATE Houses.data_cleaning
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	   WHEN SoldAsVacant = 'N' THEN 'No'
	   ELSE SoldAsVacant
	   END;
       
-- 6) Remove duplicates
WITH RowNumCTE AS(
Select *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference
				 ORDER BY UniqueID
					) row_num
FROM Houses.data_cleaning
ORDER BY ParcelID
)
DELETE
FROM RowNumCTE
WHERE row_num > 1;

-- 7) Delete Unused Columns
ALTER TABLE Houses.data_cleaning
DROP COLUMN OwnerAddress,
DROP COLUMN TaxDistrict;

-- 8) CREATE view of high-qality houses with correct sale date
CREATE OR REPLACE VIEW Houses.High_quality_Address AS
SELECT OwnerName, SaleDate AS Correct_Sale_Date, COALESCE(PropertyAddress, OwnerAddress, "Not available") AS Address, "Big" AS Quality
FROM Houses.data_cleaning
WHERE Bedrooms >= 5
UNION
SELECT OwnerName, DATE_ADD("SaleDate", INTERVAL 1 Year) AS Correct_Sale_Date,
 COALESCE(PropertyAddress, OwnerAddress, "Not available") AS Address, "New" AS Quality
FROM Houses.data_cleaning
WHERE YearBuilt >= 2014
-- WITH CHECK OPTION
;
