// Define a process where a user logs into a mobile app and retrieves their profile data.
package 'Mobile App Login Process' {
	import ScalarValues::*;

	//- Item and Value Type Definitions
	attribute def Username :> String;
	attribute def Password :> String;
	attribute def SessionToken :> String;
	attribute def ErrorMessage :> String;
	attribute def AuthenticationStatus : enumeration { success, failure };

	item def Credentials {
		attribute username : Username;
		attribute password : Password;
	}

	item def ProfileData {
		attribute fullName : String;
		attribute emailAddress : String;
	}

	item def AuthenticationRequest {
		in item credentials : Credentials;
	}

	item def AuthenticationResponse {
		attribute status : AuthenticationStatus;
		attribute token : SessionToken;
		attribute message : ErrorMessage;
	}

	item def ProfileRequest {
		in item token : SessionToken;
	}

	item def ProfileResponse {
		attribute profile : ProfileData;
	}

	//- Part Definitions for System Components
	part def MobileApp {
		port ui;
		port backend;

		state machine AppStates {
			entry;
			then LoggedOut;

			state LoggedOut;
			transition to Authenticating on accept AuthenticationRequest;

			state Authenticating;
			transition to LoggedIn on accept AuthenticationResponse { status == AuthenticationStatus::success };
			transition to Failed on accept AuthenticationResponse { status == AuthenticationStatus::failure };

			state LoggedIn;
			transition to LoggedOut on accept "logout";

			state Failed;
			transition to LoggedOut on accept "acknowledgeError";
		}
	}

	part def AuthenticationService {
		port authPort;
	}

	part def ProfileService {
		port profilePort;
	}

	//- Action Definitions for Process Steps
	action def EnterCredentials {
		out item credentials : Credentials;
	}

	action def Authenticate {
		in item request : AuthenticationRequest;
		out item response : AuthenticationResponse;
	}

	action def RequestProfile {
		in item request : ProfileRequest;
		out item response : ProfileResponse;
	}

	action def DisplayProfile {
		in item profileData : ProfileData;
	}

	action def DisplayError {
		in item message : ErrorMessage;
	}

	//- Main Action defining the overall process flow
	action def LoginAndRetrieveProfile;

	action loginProcess : LoginAndRetrieveProfile {
		// 1. User enters credentials
		first action enterCreds : EnterCredentials {
			out item credentials;
		}

		// 2. Credentials are sent to be authenticated
		flow from enterCreds.credentials to authenticateUser.request.credentials;
		then action authenticateUser : Authenticate {
			in item request;
			out item response;
		}

		// 3. Decide what to do based on authentication status
		then decision checkAuth(authenticateUser.response.status == AuthenticationStatus::success) {
			if true {
				// 4a. If successful, use token to request profile
				flow from authenticateUser.response.token to requestProfileData.request.token;
				then action requestProfileData : RequestProfile {
					in item request;
					out item response;
				}

				// 5a. Display the retrieved user profile
				flow from requestProfileData.response.profile to display.profileData;
				then action display : DisplayProfile {
					in item profileData;
				}
				then merge success;
			}
			else {
				// 4b. If failed, show an error message
				flow from authenticateUser.response.message to showError.message;
				then action showError : DisplayError {
					in item message;
				}
				then merge failure;
			}
		}
		then done;
	}

	//- System Assembly and Connections
	part def LoginSystem {
		part app : MobileApp;
		part authService : AuthenticationService;
		part profileService : ProfileService;

		// Define connections between the system components
		connect app.backend to authService.authPort;
		connect app.backend to profileService.profilePort;

		// The system as a whole performs the login process
		perform loginProcess;
	}

	//- Requirements
	requirement def SecureAuthentication {
		doc "The system shall securely authenticate a user based on their provided credentials.";
		require constraint {
			doc "Authentication credentials must be transmitted over an encrypted channel.";
		}
	}

	requirement def ProfileDataAccessibility {
		doc "A successfully authenticated user must be able to retrieve their profile data.";
		require constraint {
			doc "Profile data shall only be accessible with a valid, non-expired session token.";
		}
	}

	requirement def TimelyFeedback {
		doc "The system shall provide feedback to the user within 3 seconds of a login attempt.";
	}

	// Top-level requirements specification for the system
	requirement LoginSystemRequirements {
		doc "Specifies the high-level requirements for the mobile app login and profile retrieval functionality.";
		require secureAuth : SecureAuthentication;
		require profileAccess : ProfileDataAccessibility;
		require feedback : TimelyFeedback;
	}

	// State that the defined system satisfies the requirements
	satisfy LoginSystemRequirements by LoginSystem;
}
