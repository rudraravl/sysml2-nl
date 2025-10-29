// Define a process where a user logs into a mobile app and retrieves their profile data.
package 'MobileAppProcess' {
	part def User;
	part def MobileApp;
	item def Credentials;
	item def ProfileData;
	action def Login {
		in item credentials : Credentials;
	}
	action def RetrieveProfile {
		out item profileData : ProfileData;
	}
	action def LoginAndRetrieveProfile;
	action process : LoginAndRetrieveProfile {
		first start;
		then action provideCredentials {
			out item credentials : Credentials;
		}
		flow from provideCredentials.credentials to login.credentials;
		then action login : Login {
			in item credentials;
		}
		then action retrieveProfile : RetrieveProfile {
			out item profileData;
		}
		then action displayProfile {
			in item profileData = retrieveProfile.profileData;
		}
		then end;
	}
}
