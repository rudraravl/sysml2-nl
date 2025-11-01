// Define a library management system that is able to borrow and return books.
package LibrarySystemModel {
	private import ScalarValues::*;

	attribute def ISBN : String;
	attribute def MemberID : String;
	attribute def BookTitle : String;
	attribute def AuthorName : String;
	attribute def MemberName : String;

	enum LoanStatus {
		Available,
		OnLoan,
		Reserved
	}

	part def Book {
		attribute isbn : ISBN;
		attribute title : BookTitle;
		attribute author : AuthorName;
		state status : LoanStatus;

		state machine BookLifecycle {
			initial state Available;
			state Available;
			state OnLoan;
			state Reserved;

			transition from Available to OnLoan on borrow;
			transition from OnLoan to Available on return;
			transition from Available to Reserved on reserve;
			transition from Reserved to OnLoan on collect;
		}
	}

	part def Member {
		attribute id : MemberID;
		attribute name : MemberName;
		part borrowedBooks[0..*] : Book;
		requires interface libraryAccess : ILibraryServices;
	}

	interface def ILibraryServices {
		out action borrow(in memberId: MemberID, in bookIsbn: ISBN, out success: Boolean);
		out action return(in memberId: MemberID, in bookIsbn: ISBN, out success: Boolean);
	}

	part def Library {
		provides interface service : ILibraryServices;
		part catalog[0..*] : Book;

		action def processBorrowing(inout book : Book, inout member : Member) {
			step checkAvailability {
				assume book.status == LoanStatus::Available;
			}
			step updateBookStatus {
				do book.status = LoanStatus::OnLoan;
			}
			step assignToMember {
				bind member.borrowedBooks = (member.borrowedBooks, book);
			}
		}

		action def processReturn(inout book : Book, inout member : Member) {
			step checkLoanStatus {
				assume book.status == LoanStatus::OnLoan;
			}
			step updateBookStatus {
				do book.status = LoanStatus::Available;
			}
			step removeFromMember {
				// Abstract representation of removing the book from the member's list.
			}
		}
	}

	part def LibrarySystem {
		part library : Library;
		part members[1..*] : Member;
		connect members.libraryAccess to library.service;
	}

	requirement def BorrowingEnablement {
		subject sys : LibrarySystem;
		doc "The system shall allow registered members to borrow available books.";
	}

	requirement def ReturningEnablement {
		subject sys : LibrarySystem;
		doc "The system shall allow members to return books they have borrowed.";
	}

	requirement def ExclusiveLoan {
		subject lib : Library;
		doc "A book that is on loan shall not be available for borrowing by another member.";
		require constraint {
			forall b1: Book in lib.catalog {
				b1.status == LoanStatus::OnLoan implies
				not exists b2: Book in lib.catalog {
					b1 != b2 and b1.isbn == b2.isbn and b2.status == LoanStatus::OnLoan
				}
			}
		}
	}

	requirement def LoanTracking {
		subject sys : LibrarySystem;
		doc "The system must accurately track which books are on loan to which members.";
	}

	part system : LibrarySystem {
		part library {
			part catalog = (
				book1 : Book {
					isbn = "978-0321765723";
					title = "The C++ Programming Language";
					author = "Bjarne Stroustrup";
				},
				book2 : Book {
					isbn = "978-0132350884";
					title = "Clean Code";
					author = "Robert C. Martin";
				}
			);
		}
		part members = (
			member1 : Member {
				id = "M001";
				name = "Alice";
			},
			member2 : Member {
				id = "M002";
				name = "Bob";
			}
		);
	}

	requirement borrowingReq : BorrowingEnablement {
		subject sys = system;
	}
	requirement returningReq : ReturningEnablement {
		subject sys = system;
	}
	requirement exclusiveLoanReq : ExclusiveLoan {
		subject lib = system.library;
	}
	requirement loanTrackingReq : LoanTracking {
		subject sys = system;
	}
}
