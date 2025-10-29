// Define a library management system that is able to borrow and return books.
```sysml
package LibraryManagement {

  item def Book {
    attribute id: String;
    attribute title: String;
    attribute author: String;
    attribute isAvailable: Boolean;
  }

  item def Member {
    attribute id: String;
    attribute name: String;
  }

  action def BorrowBook {
    input member: Member;
    input book: Book;
    output success: Boolean;
  }

  action def ReturnBook {
    input member: Member;
    input book: Book;
    output success: Boolean;
  }

  part def LibraryManagementSystem {
    flow borrow: BorrowBook;
    flow return: ReturnBook;
  }

}
```
