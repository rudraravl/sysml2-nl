// Define a process where a user logs into a mobile app and retrieves their profile data.
package 'Mobile App Login Process' {
	import ISQ::*;
	import Time::*;

	//
	// Item and Value Type Definitions
	// These define the data structures exchanged between system components.
	//

	item def UserCredentials {
		attribute username : String;
		attribute password : String;
	}

	item def AuthToken {
		attribute tokenValue : String;
		attribute expiry : Instant;
	}

	item def LoginStatus {
		attribute isSuccess : Boolean;
		attribute message : String;
	}

	item def ProfileRequest {
		in item token : AuthToken;
	}

	item def UserProfile {
		attribute userId : String;
		attribute fullName : String;
		attribute emailAddress : String;
	}

	//
	// Component Action Definitions
	// These define the fundamental behaviors of the system components.
	//

	action def Authenticate {
		doc "Verifies user credentials and issues an authentication token."
		in item credentials : UserCredentials;
		out item token : AuthToken;
		out item status : LoginStatus;
	}

	action def FetchProfile {
		doc "Retrieves the user's profile data using a valid token."
		in item request : ProfileRequest;
		out item profile : UserProfile;
	}

	action def DisplayProfile {
		doc "Renders the user profile on the user interface."
		in item profile : UserProfile;
	}

	action def ShowLoginError {
		doc "Displays a login error message to the user."
		in item status : LoginStatus;
	}

	//
	// Part Definitions
	// These define the structural components of the overall system.
	//

	part def User;

	part def MobileApp {
		exhibit state LoggedOut, Authenticating, LoggedIn, LoginFailed;
	}

	part def AuthenticationServer {
		perform Authenticate;
	}

	part def ProfileServer {
		perform FetchProfile;
	}

	part def BackendSystem {
		part authServer : AuthenticationServer;
		part profileServer : ProfileServer;
	}

	//
	// System-Level Behavior
	// This action defines the complete end-to-end login and profile retrieval process.
	//

	action def RetrieveProfileProcess {
		// 1. User provides credentials.
		first action enterCredentials {
			doc "User inputs their username and password into the mobile app."
			out item credentials : UserCredentials;
		}

		// 2. Credentials are sent for authentication.
		then action authenticate : Authenticate {
			in item credentials = enterCredentials.credentials;
		}

		// 3. The result of the authentication attempt is checked.
		then decide (authenticate.status.isSuccess) {
			// 4a. If successful, the received token is used to request the profile.
			true then {
				action createRequest : ProfileRequest {
					in item token = authenticate.token;
				}
				flow from createRequest.self to fetchProfile.request;

				action fetchProfile : FetchProfile {
					in item request;
					out item profile;
				}
				flow from fetchProfile.profile to displayProfile.profile;

				// 5. The retrieved profile is displayed to the user.
				action displayProfile : DisplayProfile {
					in item profile;
				}
				then success;
			}
			// 4b. If failed, an error message is shown.
			false then {
				action showError : ShowLoginError {
					in item status = authenticate.status;
				}
				then failure;
			}
		}
	}

	//
	// Requirements
	// These define the constraints and goals for the system.
	//

	requirement def SecureAuthentication {
		id = "REQ-SEC-001";
		text "The system shall use a secure, token-based mechanism for all authenticated user actions.";
	}

	requirement def TimelyResponse {
		id = "REQ-PERF-001";
		text "The user profile shall be retrieved and displayed within 3 seconds of a successful login.";
	}

	//
	// System Instantiation and Verification
	// This section defines a concrete instance of the system and links requirements.
	//

	part system 'User Login System' {
		part user : User;
		part app : MobileApp;
		part backend : BackendSystem;

		connect app to backend;

		// The system as a whole performs the defined process.
		perform process : RetrieveProfileProcess;

		// The authentication action satisfies the security requirement.
		satisfy SecureAuthentication by process.authenticate;
	}
}
