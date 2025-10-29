// Define a library management system that is able to borrow and return books.
package LibraryManagement {
	part def Book;
	part def User;

	part def Library {
		part managedBooks : Book[0..*];

		action borrowBook {
			in book : Book;
			in borrower : User;
		}
		action returnBook {
			in book : Book;
			in returner : User;
		}
	}

	part myLibrarySystem : Library;
}
