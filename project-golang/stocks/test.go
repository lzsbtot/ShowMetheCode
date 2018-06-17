package main

import (
    "database/sql"
    //    "encoding/json"
    "bufio"
    "fmt"
    "io/ioutil"
    "net/http"
    "os"
    "strconv"
    "strings"

    "github.com/go-sql-driver/mysql"
)

// show columns from XXXX get the property of each columns
var ShenZhenStartupPrefix string = "300"
var ShenZhenMiddleLittePrefix string = "002"
var ShenZhenMainPrefix string = "000"
var ShangHaiMainPrefix string = "60"
var YahooGetHistoryURL string = "http://table.finance.yahoo.com/table.csv?s="

type StockInfo struct {
    Name   string
    Code   string
    Date   string
    Open   float64
    High   float64
    Low    float64
    Close  float64
    Volume uint64
    Adj    float64
}

type prefixError struct {
    Code  int
    Stock string
}

func (e prefixError) Error() string {
    return fmt.Sprintf("Unknown Stock Code %s, Error code is %d", e.Stock, e.Code)
}

func getStockSuffix(code string) (string, error) {
    if strings.HasPrefix(code, ShenZhenStartupPrefix) {
        return "sz", nil
    } else if strings.HasPrefix(code, ShenZhenMiddleLittePrefix) {
        return "sz", nil
    } else if strings.HasPrefix(code, ShenZhenMainPrefix) {
        return "sz", nil
    } else if strings.HasPrefix(code, ShangHaiMainPrefix) {
        return "ss", nil
    } else {
        return "", prefixError{Code: -1, Stock: code}
    }
}

func dropAllTables() {
    db, err := sql.Open("mysql", "root:wasd1234@tcp(47.254.39.198:3306)/stock_yahoo?charset=utf8")
    checkError(err)
    defer db.Close()
    tables, err := db.Query("show table status from yahoo")
    for tables.Next() {
        var name sql.NullString
        tables.Scan(&name)
        col, _ := tables.Columns()
        fmt.Println(col)
        fmt.Println(name)
    }
}

func httpGet() {
    db, err := sql.Open("mysql", "root:wasd1234@tcp(47.254.39.198:3306)/stock_yahoo?charset=utf8")
    checkError(err)

    file, err := os.Open("./stock.mk")
    checkError(err)

    buf := bufio.NewReader(file)
    for {

        line, err := buf.ReadString('\n')
        if err != nil {
            break
        }

        line = strings.TrimSpace(line)

        suffix, err := getStockSuffix(line)
        if err != nil {
            fmt.Println(err.Error)
            continue
        }

        table := suffix + line

        url := YahooGetHistoryURL + line + "." + suffix
        fmt.Println(url)
        req, err := http.Get(url)
        checkError(err)

        result, err := ioutil.ReadAll(req.Body)
        checkError(err)

        defer req.Body.Close()
        //fmt.Println(string(result))

        _, err = db.Query("select * from " + table)
        if err != nil {
            _, err := db.Query("CREATE TABLE " + table + " (Date char(64) not null primary key, Open double not null, High double not null, Low double not null, Close double not null, Volume bigint(64) not null, Adj double not null)")
            checkError(err)
        }

        str := strings.Split(string(result), "\n")
        for i, r := range str {
            //fmt.Println(r)
            if i == 0 {
                continue
            }

            if len(r) == 0 {
                continue
            }

            token := strings.Split(r, ",")
            var stock StockInfo
            stock.Date = token[0]
            stock.Open, _ = strconv.ParseFloat(token[1], 64)
            stock.High, _ = strconv.ParseFloat(token[2], 64)
            stock.Low, _ = strconv.ParseFloat(token[3], 64)
            stock.Close, _ = strconv.ParseFloat(token[4], 64)
            stock.Volume, _ = strconv.ParseUint(token[5], 10, 64)
            stock.Adj, _ = strconv.ParseFloat(token[6], 64)
            fmt.Println(stock)
            insert, err := db.Prepare("INSERT " + table + " SET Date=?, Open=?, High=?, Low=?, Close=?, Volume=?, Adj=?")
            checkError(err)

            _, err = insert.Exec(stock.Date, stock.Open, stock.High, stock.Low, stock.Close, stock.Volume, stock.Adj)
            checkError(err)
        }

    }
}

func main() {
    //dropAllTables()
    httpGet()
}

func checkError(err error) {
    if err != nil {
        if driverErr, ok := err.(*mysql.MySQLError); ok {
            if driverErr.Number == 1062 {
                return
            }
        }
        fmt.Println(err.Error())
        fmt.Println(err)
    }
}
