import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(BingoGame());
}

const ip = '172.20.10.4'; // 伺服器IP
const port = 12345; // 伺服器 port number

late Socket socket; // 記錄此 client 端的 socket

//BingoGame: 主 UI 部分
class BingoGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bingo Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        backgroundColor: Color.fromARGB(255, 163, 226, 255),
        appBar: AppBar(
          title: Text(
            'Bingo Game!!',
            style: TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          centerTitle: true,
        ),
        body: BingoBoard(),
      ),
    );
  }
}

//宣告 BingoBoard 的狀態控制變數
class BingoBoard extends StatefulWidget {
  @override
  _BingoBoardState createState() => _BingoBoardState();
}

//BingoBoardState: 數字板和按鈕控制
class _BingoBoardState extends State<BingoBoard> {
  List<List<int?>> board =
      List.generate(5, (_) => List.filled(5, null)); // Bingo 表: 記錄玩家填入的Bingo數字
  int nextNumber = 1; // 記錄填寫到第幾個數字
  int serverSendNumber = 0; // 記錄遊戲開始階段從伺服器接收的數字
  bool checkBingo = false; // 記錄玩家 Bingo 狀態
  bool gameStart = false; // 記錄遊戲是否進入開始階段
  bool ready = false; // 記錄玩家是否進入準備階段

  @override
  // 變數初始化: 將所有的變數初始化
  void initState() {
    super.initState();
    board = List.generate(5, (_) => List.filled(5, null));
    ready = false;
    gameStart = false;
    serverSendNumber = 0;
    checkBingo = false;
    connectToServer();
  }

  // 建立客戶端 Socket 並連接到伺服器
  void connectToServer() async {
    try {
      socket = await Socket.connect(ip, port);
      print('Connected to server');

      // socket.listen: client 接收到 server 傳來的訊息，執行對應的程序
      socket.listen(
        (List<int> event) {
          String response = utf8.decode(event);
          print('Server response: $response');
          if (response == 'start' && ready) {
            // 接收到 server 傳來的 start 訊號，進入遊戲開始階段
            setState(() {
              gameStart = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              // Game Start 提示
              const SnackBar(
                content: Center(
                  child: Text(
                    "Game Start!!",
                    textAlign: TextAlign.center,
                  ),
                ),
                duration: Duration(seconds: 3),
              ),
            );
            socket.write('getStart'); // 通知 server 有收到 start 訊號
          } else if (response == 'Loss') {
            // server 傳來輸家訊號
            socket.close(); // 關閉 socket 連線
            print('socket connection close');
            switchToLosserUI(); // 將介面切換到 LosserUI
          } else if (response == 'Win') {
            // server 傳來贏家訊號
            socket.close(); // 關閉 socket 連線
            print('socket connection close');
            switchToWinnerUI(); // 將介面切換到 WinnerUI
          } else if ((int.parse(response) <= 25 && int.parse(response) >= 1) &&
              gameStart) {
            // 接收到 server 傳來的隨機數字
            print("Received number from server: $response");
            setState(() {
              // 更新 Bingo 表的狀態，收到的數字位置更新為 '0'
              serverSendNumber = int.parse(response);
              bool find = false;
              for (int i = 0; i < 5; i++) {
                for (int j = 0; j < 5; j++) {
                  if (board[i][j] == serverSendNumber) {
                    board[i][j] = 0;
                    find = true;
                    break;
                  }
                }
                if (find) break;
              }
            });
            CheckBingo(); // Bingo 連線狀態確認
            if (checkBingo) {
              Future.delayed(Duration(seconds: 5), () {
                socket.write('Bingo'); // 通知 server Bingo 連線
              });
            } else
              Future.delayed(Duration(seconds: 5), () {
                socket.write(response); // 通知　server 有收到隨機的數字
              });
          }
        },
        onError: (error) {
          print('Socket error: $error');
        },
        onDone: () {
          print('Server connection closed');
          socket.destroy();
        },
      );
    } catch (e) {
      print('Error connecting to server: $e');
    }
  }

  // 檢查是否達成 Bingo
  void CheckBingo() {
    // 橫線
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        if (board[i][j] != 0)
          break;
        else if (j == 4) checkBingo = true;
      }
      if (checkBingo) break;
    }

    // 縱線
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        if (board[j][i] != 0)
          break;
        else if (j == 4) checkBingo = true;
      }
      if (checkBingo) break;
    }

    // 左上到右下的斜線
    for (int i = 0; i < 5; i++) {
      if (board[i][i] != 0)
        break;
      else if (i == 4) checkBingo = true;
    }

    // 右上到左下的斜線
    for (int i = 0; i < 5; i++) {
      if (board[i][4 - i] != 0)
        break;
      else if (i == 4) checkBingo = true;
    }
  }

  // 標記指定的行和列上的數字並更新 UI
  void markNumber(int row, int col) {
    setState(() {
      board[row][col] = nextNumber++;
    });
  }

  // 切換到 WinnerUI
  void switchToWinnerUI() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => WinnerUI()),
    );
  }

  // 切換到 LosserUI
  void switchToLosserUI() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LosserUI()),
    );
  }

  // 將剩餘的數字填入空格並更新 UI
  void fillRemainingNumbers() {
    List<int> remainingNumbers = List.generate(25, (index) => index + 1);
    remainingNumbers
        .removeWhere((number) => board.any((row) => row.contains(number)));

    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        if (board[i][j] == null) {
          if (remainingNumbers.isNotEmpty) {
            int randomNumberIndex = Random().nextInt(remainingNumbers.length);
            setState(() {
              board[i][j] = remainingNumbers[randomNumberIndex];
              remainingNumbers.removeAt(randomNumberIndex);
            });
          } else {
            return;
          }
        }
      }
    }
  }

  // 清空所有格子中的數字
  void clearBoard() {
    setState(() {
      board = List.generate(5, (_) => List.filled(5, null));
      nextNumber = 1;
      ready = false;
    });
  }

  // 檢查是否所有的格子都已填入數字，然後發送 ready 訊號到伺服器並進入等待階段
  void checkIfAllNumbersFilled() {
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 5; j++) {
        if (board[i][j] == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Please fill all cells before ready!'), // 當格字沒有被填滿，出現提示字
          ));
          return;
        }
      }
    }
    socket.write('ready');
    setState(() {
      ready = true;
    });
  }

  @override // 建立 Bingo 表的方塊物件和相關按鈕物件
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 50),
        Expanded(
          child: GridView.builder(
            itemCount: 25,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5),
            itemBuilder: (context, index) {
              int row = index ~/ 5;
              int col = index % 5;
              return GestureDetector(
                onTap: () {
                  if (board[row][col] == null) {
                    markNumber(row, col);
                  }
                },
                child: Container(
                  margin: EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    border: Border.all(),
                    color: board[row][col] == 0
                        ? Color.fromARGB(255, 102, 186, 255)
                        : Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      (board[row][col] == null || board[row][col] == 0)
                          ? ''
                          : '${board[row][col]}',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // 如果玩家尚未準備且遊戲尚未開始，顯示 '隨機填入' 、 '清空方塊' 和 '準備' 按鈕
        if (!ready && !gameStart) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                width: 150,
                child: ElevatedButton(
                  onPressed: () {  // '隨機填入' 按鈕觸發事件
                    fillRemainingNumbers();  // 填入剩餘數字
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 0, 140, 255),
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('隨機填入',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              SizedBox(
                width: 150,
                child: ElevatedButton(
                  onPressed: () {  // '清空方塊' 按鈕觸發事件
                    clearBoard(); // 清空所有方塊內的數字
                  },
                  child: Text('清空方塊',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 0, 140, 255),
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            width: 150,
            child: ElevatedButton(  // '準備' 按鈕觸發事件
              onPressed: () {
                checkIfAllNumbersFilled();  // 確定是否有填滿，並作相對應的動作
              },
              child: Text('準備', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 0, 140, 255),
                foregroundColor: Colors.white,
                elevation: 5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],

        // 如果玩家已準備但遊戲尚未開始，顯示等待其他玩家的進度指示器
        if (ready && !gameStart) ...[
          CircularProgressIndicator(),
          SizedBox(height: 8),
          Text(
            'Waiting Other Players',
            style: TextStyle(fontSize: 18),
          ),
        ],

        // 如果玩家已準備且遊戲已開始，顯示伺服器發送的數字
        if (ready && gameStart) ...[
          SizedBox(
            child: Center(
              child: Text(
                'Server send number:',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Container(
            height: 100,
            color: Color.fromARGB(255, 102, 186, 255),
            child: Center(
              child: Text(
                '$serverSendNumber',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 50,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// 贏家界面
class WinnerUI extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Win!!',
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              child: Text('Terminate'),
            ),
          ],
        ),
      ),
    );
  }
}

// 輸家界面
class LosserUI extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Loss!!',
              style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              child: Text('Terminate'),
            ),
          ],
        ),
      ),
    );
  }
}
