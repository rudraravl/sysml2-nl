// Define a process where a user logs into a mobile app and retrieves their profile data.
```sysml
process def UserLoginAndProfileRetrieval {
    action LoginToApp {
        input credentials: Credentials;
        output sessionToken: SessionToken;
    }

    action RetrieveProfile {
        input sessionToken: SessionToken;
        output profileData: ProfileData;
    }

    flow LoginToApp.sessionToken -> RetrieveProfile.sessionToken;
}

type def Credentials;
type def SessionToken;
type def ProfileData;
```
