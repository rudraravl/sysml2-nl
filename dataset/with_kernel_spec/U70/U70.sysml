package HongKongMedicalFairManagement {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def DataRateValue;

		attribute def ExhibitorProfile {
			attribute companyName : String;
			attribute sector : String;
			attribute products : String[1..*];
			attribute targetMarkets : String[1..*];
		}
		attribute def VisitorProfile {
			attribute fullName : String;
			attribute professionalRole : String;
			attribute interests : String[1..*];
		}
		attribute def BusinessLead {
			attribute exhibitorId : String;
			attribute visitorId : String;
			attribute matchedOn : String;
			attribute timestamp : TimeValue;
		}
		attribute def FeedbackEntry {
			attribute participantId : String;
			attribute rating : Real;
			attribute comments : String;
		}
		attribute def AnalyticsReport {
			attribute totalVisitors : Integer;
			attribute totalExhibitors : Integer;
			attribute totalLeads : Integer;
			attribute averageSatisfaction : Real;
			attribute roi : Real;
			attribute generatedAt : TimeValue;
		}
		attribute def EmergencyType :> String;

		attribute def FairOpens;
		attribute def EmergencyTriggered;
		attribute def EmergencyResolved;
		attribute def FairCloses;

		port def UtilityPort {
			in power : PowerValue;
			in network : DataRateValue;
		}
		port def RegistrationPort {
			in exhibitorProfile : ExhibitorProfile;
			in visitorProfile : VisitorProfile;
			out confirmationId : String;
		}
		port def MatchingPort {
			in exhibitorProfile : ExhibitorProfile;
			in visitorProfile : VisitorProfile;
			out recommendation : String;
		}
		port def InfoPort {
			in query : String;
			out response : String;
		}
		port def LeadPort {
			out lead : BusinessLead;
		}
		port def FeedbackPort {
			in feedback : FeedbackEntry;
		}

		part def Exhibitor {
			attribute exhibitorId : String;
			attribute profile : ExhibitorProfile;
			port registration : ~RegistrationPort;
			port matching : ~MatchingPort;
			port leadCollection : ~LeadPort;
		}
		part def Visitor {
			attribute visitorId : String;
			attribute profile : VisitorProfile;
			port registration : ~RegistrationPort;
			port matching : ~MatchingPort;
			port info : ~InfoPort;
			port feedback : ~FeedbackPort;
		}
		part def Booth {
			attribute boothNumber : String;
			attribute area : AreaValue;
			attribute powerAvailable : Boolean = true;
			attribute networkAvailable : Boolean = true;
			port utility : UtilityPort;
			ref part allocatedExhibitor : Exhibitor[0..1];
		}
		part def ExhibitionHall {
			attribute hallName : String;
			part booths : Booth[1..*];
		}
		part def Venue {
			part halls : ExhibitionHall[3];
		}
		part def RegistrationCenter {
			port registration : RegistrationPort;
		}
		part def BusinessMatchingCenter {
			port matching : MatchingPort;
			port leadCollection : LeadPort;
		}
		part def EventCoordination {
			attribute seminarSchedule : String[0..*];
		}
		part def InformationDesk {
			port info : InfoPort;
		}
		part def FairManagementSystem {
			part venue : Venue;
			part registrationCenter : RegistrationCenter;
			part businessMatchingCenter : BusinessMatchingCenter;
			part eventCoordination : EventCoordination;
			part informationDesks : InformationDesk[1..*];
			part exhibitors : Exhibitor[1..*];
			part visitors : Visitor[1..*];
			port utilitySupply : ~UtilityPort;
			port feedbackCollection : FeedbackPort;
			perform fairLifecycle : FairLifecycle;
		}

		action def RegisterExhibitor {
			in profile : ExhibitorProfile;
			out exhibitorId : String;
			out assignedBooth : Booth;
		}
		action def RegisterVisitor {
			in profile : VisitorProfile;
			out visitorId : String;
		}
		action def MatchProfiles {
			in exhibitorProfiles : ExhibitorProfile[0..*];
			in visitorProfiles : VisitorProfile[0..*];
			out leads : BusinessLead[0..*];
		}
		action def CollectLead {
			in exhibitorId : String;
			in visitorId : String;
			out lead : BusinessLead;
		}
		action def CollectFeedback {
			in participantId : String;
			out feedbackEntry : FeedbackEntry;
		}
		action def GenerateAnalytics {
			in feedbacks : FeedbackEntry[0..*];
			in leads : BusinessLead[0..*];
			in attendance : Integer;
			out report : AnalyticsReport;
		}
		action def ScheduleSeminar {
			in topic : String;
			in timeSlot : TimeValue;
			in location : String;
			out eventId : String;
		}
		action def ConductDemo {
			in exhibitorId : String;
			in product : String;
		}
		action def AnswerQuery {
			in question : String;
			out response : String;
		}
		action def HandleEmergency {
			in emergencyType : EmergencyType;
			out clearanceStatus : Boolean;
		}

		state machine def FairLifecycle {
			state Preparation {
				entry action registerExhibitors : RegisterExhibitor;
				entry action registerVisitors : RegisterVisitor;
			}
			state Operational {
				do action matchProfiles : MatchProfiles;
				do action scheduleSeminars : ScheduleSeminar;
				do action conductDemos : ConductDemo;
				do action answerQueries : AnswerQuery;
			}
			state Emergency {
				entry action handleEmergency : HandleEmergency;
			}
			state Closing {
				entry action collectFeedback : CollectFeedback;
				entry action generateAnalytics : GenerateAnalytics;
			}
			transition from Preparation to Operational accept FairOpens;
			transition from Operational to Emergency accept EmergencyTriggered;
			transition from Emergency to Operational accept EmergencyResolved;
			transition from Operational to Closing accept FairCloses;
		}

		requirement def RegistrationRequirement {
			doc "The system shall handle registration and check-in of all exhibitors and visitors.";
		}
		requirement def MatchingRequirement {
			doc "The system shall intelligently connect exhibitors with relevant visitors based on their profiles.";
		}
		requirement def EventRequirement {
			doc "The system shall coordinate seminars and live product demonstrations during the fair.";
		}
		requirement def EmergencyRequirement {
			doc "The system shall provide emergency handling protocols and guide participants to safety.";
		}
		requirement def AnalyticsRequirement {
			doc "The system shall collect feedback and generate a comprehensive post-event analytics report.";
		}
		requirement def BoothAllocationRequirement {
			doc "Each exhibitor must be allocated a booth equipped with power and network utilities.";
		}
	}

	package Usages {
		part fairSystem : Definitions::FairManagementSystem {
			connect exhibitors.registration to registrationCenter.registration;
			connect visitors.registration to registrationCenter.registration;
			connect exhibitors.matching to businessMatchingCenter.matching;
			connect visitors.matching to businessMatchingCenter.matching;
			connect visitors.info to informationDesks.info;
			connect exhibitors.leadCollection to businessMatchingCenter.leadCollection;
			connect visitors.feedback to feedbackCollection;
			connect venue.halls.booths.utility to utilitySupply;
		}

		requirement regReq : Definitions::RegistrationRequirement;
		requirement matchReq : Definitions::MatchingRequirement;
		requirement eventReq : Definitions::EventRequirement;
		requirement emerReq : Definitions::EmergencyRequirement;
		requirement analyticsReq : Definitions::AnalyticsRequirement;
		requirement boothReq : Definitions::BoothAllocationRequirement;

		satisfy regReq by fairSystem.registrationCenter;
		satisfy matchReq by fairSystem.businessMatchingCenter;
		satisfy eventReq by fairSystem.eventCoordination;
		satisfy emerReq by fairSystem;
		satisfy analyticsReq by fairSystem;
		satisfy boothReq by fairSystem.venue;
	}
}
