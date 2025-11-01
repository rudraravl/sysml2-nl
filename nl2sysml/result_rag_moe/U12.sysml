// Define a library management system that is able to borrow and return books.
package LibraryManagementSystem {
	import ScalarValues::*;

	// --- Value, Item, and State Definitions ---

	attribute def ISBN :> String;
	attribute def MemberID :> String;

	state machine def BookLifecycle {
		initial state Available;
		state OnLoan;

		transition borrow from Available to OnLoan;
		transition return from OnLoan to Available;
	}

	item def Book {
		attribute isbn : ISBN;
		attribute title : String;
		attribute author : String;
		state status : BookLifecycle;
	}

	item def Member {
		attribute memberId : MemberID;
		attribute name : String;
	}

	item def LoanRecord {
		ref book : Book;
		ref member : Member;
	}

	// --- Port and Part Definitions ---

	port def LibraryServices {
		in action borrow(in memberId : MemberID, inout book : Book);
		in action return(inout book : Book);
	}

	part def Library {
		port services : LibraryServices;

		part books[*] : Book;
		part members[*] : Member;
		part loans[*] : LoanRecord;

		action borrow(in memberId : MemberID, inout book : Book) {
			let member = self.members->select(m | m.memberId == memberId)->first();

			if member <> null and book.status == BookLifecycle::Available {
				let newLoan = LoanRecord {
					book = book,
					member = member
				};
				self.loans->add(newLoan);
				accept book.borrow;
			}
		}

		action return(inout book : Book) {
			if book.status == BookLifecycle::OnLoan {
				let loanToRemove = self.loans->select(l | l.book == book)->first();
				if loanToRemove <> null {
					self.loans->remove(loanToRemove);
					accept book.return;
				}
			}
		}

		bind services.borrow = self.borrow;
		bind services.return = self.return;
	}

	part def User {
		attribute memberId : MemberID;
		port library :> LibraryServices;
	}

	// --- System Definition and Instantiation ---

	part def LibrarySystem;

	part system : LibrarySystem {
		part library : Library {
			part books[2] = (
				Book {
					isbn = "978-0321927866";
					title = "SysML Distilled";
					author = "Lenny Delligatti";
				},
				Book {
					isbn = "978-0128002025";
					title = "A Practical Guide to SysML";
					author = "Sanford Friedenthal";
				}
			);
			part members[1] = (
				Member {
					memberId = "M001";
					name = "Jane Doe";
				}
			);
		}

		part user : User {
			memberId = "M001";
		}

		connect user.library to library.services;
	}

	// --- Requirements ---

	requirement def SystemFunctionality {
		subject library : Library;
		doc "The library system shall manage the borrowing and returning of books.";

		requirement Borrowing {
			doc "The system shall allow a registered member to borrow a book that is currently available.";
		}

		requirement Returning {
			doc "The system shall allow a member to return a borrowed book, making it available again.";
		}

		requirement LoanTracking {
			doc "The system must maintain a record of each active loan, linking the book to the member who borrowed it.";
		}
	}

	require systemReq : SystemFunctionality {
		subject system.library;
		require borrowReq : Borrowing;
		require returnReq : Returning;
		require loanTrackReq : LoanTracking;
	}
}
