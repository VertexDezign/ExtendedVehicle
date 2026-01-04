---@class TableUtils
TableUtils = {}

---Returns the index of an element in a table
---@param table table the table to search in
---@param element any the element to look for
---@return integer the index of the element, or -1 if not found
function TableUtils.indexOf(table, element)
    for i, v in ipairs(table) do
        if v == element then
            return i
        end
    end

    return -1
end

---@param t table
---@param predicate function
function TableUtils.anyMatch(t, predicate)
    for _, v in pairs(t) do
        if predicate(v) then return true end
    end
    return false
end