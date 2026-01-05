package 'Hong Kong International Medical and Healthcare Fair System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ExhibitorID :> String;
	attribute def VisitorID :> String;
	attribute def BoothID :> String;
	attribute def ProductCategory :> String;
	attribute def SessionID :> String;
	
	attribute def AreaValue :> Real;
	attribute def AttendeeCount :> Integer;
	attribute def BoothCount :> Integer;
	attribute def MatchScore :> Real;
	
	enum def RegistrationStatus {
		pending;
		confirmed;
		checkedIn;
		cancelled;
	}
	
	enum def EventCategory {
		exhibition;
		seminar;
		productDemonstration;
		businessMatching;
		networking;
	}
	
	enum def ProductSector {
		diagnosticEquipment;
		therapeuticDevices;
		pharmaceuticals;
		digitalHealth;
		rehabilitationProducts;
		hospitalSupplies;
	}
	
	item def RegistrationData {
		attribute participantID : String;
		attribute organizationName : String;
		attribute contactEmail : String;
		attribute status : RegistrationStatus;
	}
	
	item def ExhibitorProfile {
		attribute exhibitorID : ExhibitorID;
		attribute companyName : String;
		attribute productSectors : ProductSector[1..*];
		attribute targetMarkets : String[*];
		attribute boothRequirement : AreaValue;
	}
	
	item def VisitorProfile {
		attribute visitorID : VisitorID;
		attribute professionalRole : String;
		attribute interests : ProductSector[*];
		attribute purchasingAuthority : Boolean;
	}
	
	item def BusinessLead {
		attribute exhibitorID : ExhibitorID;
		attribute visitorID : VisitorID;
		attribute interactionType : String;
		attribute followUpPriority : String;
		attribute timestamp : String;
	}
	
	item def SeminarContent {
		attribute sessionID : SessionID;
		attribute topic : String;
		attribute speaker : String;
		attribute duration : DurationValue;
		attribute targetAudience : String;
	}
	
	port def RegistrationPort {
		in registrationRequest : RegistrationData;
		out confirmationStatus : RegistrationStatus;
		out accessCredentials : String;
	}
	
	port def BoothManagementPort {
		in boothRequest : AreaValue;
		out assignedBooth : BoothID;
		in setupRequirements : String;
	}
	
	port def MatchingServicePort {
		in exhibitorProfile : ExhibitorProfile;
		in visitorProfile : VisitorProfile;
		out matchRecommendations : BusinessLead[*];
		out meetingSchedule : String;
	}
	
	port def InformationPort {
		in query : String;
		out response : String;
		out directionalGuidance : String;
	}
	
	port def EventSchedulingPort {
		in eventRequest : SeminarContent;
		out scheduledTime : String;
		out venueAssignment : String;
	}
	
	part def ExhibitionBooth {
		attribute boothID : BoothID;
		attribute allocatedArea : AreaValue;
		attribute location : String;
		attribute sector : ProductSector;
		ref part occupyingExhibitor : Exhibitor[0..1];
		port powerSupply;
		port networkConnection;
	}
	
	part def Exhibitor {
		attribute profile : ExhibitorProfile;
		attribute registrationStatus : RegistrationStatus;
		attribute leadsCollected : BusinessLead[*];
		port registration : RegistrationPort;
		port boothAccess : BoothManagementPort;
		port matchingService : MatchingServicePort;
	}
	
	part def Visitor {
		attribute profile : VisitorProfile;
		attribute registrationStatus : RegistrationStatus;
		attribute visitedBooths : BoothID[*];
		port registration : RegistrationPort;
		port informationAccess : InformationPort;
		port matchingService : MatchingServicePort;
	}
	
	part def ExhibitionHall {
		attribute hallName : String;
		attribute totalArea : AreaValue;
		attribute capacity : BoothCount;
		part booths : ExhibitionBooth[*];
		port hallManagement;
		port utilities;
	}
	
	part def RegistrationCenter {
		attribute totalExhibitorsRegistered : AttendeeCount;
		attribute totalVisitorsRegistered : AttendeeCount;
		port exhibitorRegistration : ~RegistrationPort;
		port visitorRegistration : ~RegistrationPort;
		port dataManagement;
	}
	
	part def SeminarVenue {
		attribute venueName : String;
		attribute seatingCapacity : AttendeeCount;
		attribute audioVisualEquipment : Boolean;
		part scheduledSeminars : SeminarSession[*];
		port scheduling : EventSchedulingPort;
	}
	
	part def SeminarSession {
		attribute content : SeminarContent;
		attribute attendees : AttendeeCount;
		attribute actualStartTime : String;
	}
	
	part def BusinessMatchingCenter {
		attribute activeMatches : Integer;
		attribute meetingsScheduled : Integer;
		port exhibitorMatching : ~MatchingServicePort;
		port visitorMatching : ~MatchingServicePort;
		port analytics;
	}
	
	part def InformationDesk {
		attribute deskLocation : String;
		attribute staffCount : Integer;
		port informationService : ~InformationPort;
		port navigation;
	}
	
	part def EventCoordination {
		attribute dailySchedule : String;
		part seminars : SeminarVenue[*];
		part demonstrations : ProductDemonstration[*];
		port coordination;
		port scheduling : ~EventSchedulingPort;
	}
	
	part def ProductDemonstration {
		attribute demonstrationID : String;
		attribute productName : String;
		attribute demonstrator : String;
		attribute timeSlot : String;
		ref part hostBooth : ExhibitionBooth;
	}
	
	action def RegisterParticipant {
		in participantData : RegistrationData;
		in participantType : String;
		out confirmationStatus : RegistrationStatus;
		out credentials : String;
	}
	
	action def AssignBooth {
		in exhibitorProfile : ExhibitorProfile;
		in requestedArea : AreaValue;
		in preferredSector : ProductSector;
		out assignedBooth : ExhibitionBooth;
		out setupInstructions : String;
	}
	
	action def MatchBusinessPartners {
		in exhibitorProfiles : ExhibitorProfile[*];
		in visitorProfiles : VisitorProfile[*];
		out matches : BusinessLead[*];
		out recommendations : String[*];
	}
	
	action def ScheduleSeminar {
		in seminarContent : SeminarContent;
		in preferredTime : String;
		out confirmedSchedule : String;
		out assignedVenue : String;
	}
	
	action def ProvideInformation {
		in visitorQuery : String;
		in currentLocation : String;
		out informationResponse : String;
		out navigationGuidance : String;
	}
	
	action def CollectFeedback {
		in participantID : String;
		in feedbackData : String;
		out acknowledgment : Boolean;
	}
	
	action def GenerateAnalytics {
		in exhibitorData : ExhibitorProfile[*];
		in visitorData : VisitorProfile[*];
		in businessLeads : BusinessLead[*];
		out attendanceReport : String;
		out engagementMetrics : String;
		out roiAnalysis : String;
	}
	
	action def ConductFair {
		in fairDuration : DurationValue;
		in maxExhibitors : BoothCount;
		in maxVisitors : AttendeeCount;
		out fairCompletionStatus : Boolean;
		out finalReport : String;
		
		first start;
		then merge preparationPhase;
		
		action preparationPhase {
			doc /* Pre-event setup including registration processing and booth allocation */
			
			action processExhibitorRegistrations : RegisterParticipant[*] {
				in participantData;
				in participantType = "Exhibitor";
				out confirmationStatus;
				out credentials;
			}
			
			then action allocateBooths : AssignBooth[*] {
				in exhibitorProfile;
				in requestedArea;
				in preferredSector;
				out assignedBooth;
				out setupInstructions;
			}
			
			then action scheduleSeminars : ScheduleSeminar[*] {
				in seminarContent;
				in preferredTime;
				out confirmedSchedule;
				out assignedVenue;
			}
		}
		
		then merge operationalPhase;
		
		action operationalPhase {
			doc /* Main fair operations including visitor management and business facilitation */
			
			action processVisitorRegistrations : RegisterParticipant[*] {
				in participantData;
				in participantType = "Visitor";
				out confirmationStatus;
				out credentials;
			}
			
			flow processVisitorRegistrations.credentials to facilitateInteractions.visitorCredentials;
			
			action facilitateInteractions {
				in visitorCredentials : String;
				
				action provideInformation : ProvideInformation[*] {
					in visitorQuery;
					in currentLocation;
					out informationResponse;
					out navigationGuidance;
				}
				
				action matchPartners : MatchBusinessPartners[*] {
					in exhibitorProfiles;
					in visitorProfiles;
					out matches;
					out recommendations;
				}
			}
			
			action conductEvents {
				action runSeminars[*];
				action runDemonstrations[*];
				action facilitateNetworking[*];
			}
		}
		
		then merge closingPhase;
		
		action closingPhase {
			doc /* Post-event activities including feedback collection and reporting */
			
			action collectFeedback : CollectFeedback[*] {
				in participantID;
				in feedbackData;
				out acknowledgment;
			}
			
			then action generateAnalytics : GenerateAnalytics {
				in exhibitorData;
				in visitorData;
				in businessLeads;
				out attendanceReport;
				out engagementMetrics;
				out roiAnalysis;
			}
			
			flow generateAnalytics.attendanceReport to finalReport;
		}
		
		then assign fairCompletionStatus := true;
		then done;
	}
	
	state def FairLifecycle {
		entry; then preparation;
		
		state preparation {
			doc /* Fair is in setup phase */
		}
		
		transition setupComplete
			first preparation
			accept setupSignal : Boolean
			then active;
		
		state active {
			doc /* Fair is open to participants */
		}
		
		transition emergencyOccurs
			first active
			accept emergencyAlert : String
			then emergency;
		
		state emergency {
			doc /* Emergency procedures activated */
			entry action handleEmergency;
		}
		
		transition emergencyResolved
			first emergency
			accept clearanceSignal : Boolean
			then active;
		
		transition fairEnds
			first active
			accept closingSignal : Boolean
			then closed;
		
		state closed {
			doc /* Fair has concluded */
			entry action finalizeOperations;
		}
	}
	
	part def MedicalHealthcareFairSystem {
		doc /* 
		Integrated system managing all aspects of the Hong Kong International 
		Medical and Healthcare Fair, from registration through post-event analytics.
		*/
		
		part exhibitionHalls : ExhibitionHall[3];
		part registrationCenter : RegistrationCenter;
		part eventCoordination : EventCoordination;
		part businessMatchingCenter : BusinessMatchingCenter;
		part informationDesks : InformationDesk[5];
		part exhibitors : Exhibitor[*];
		part visitors : Visitor[*];
		
		port systemManagement;
		port externalCommunications;
	}
	
	part hongKongMedicalFair : MedicalHealthcareFairSystem {
		doc /* 
		The Hong Kong International Medical and Healthcare Fair system facilitates 
		comprehensive trade exhibitions connecting global medical and healthcare 
		manufacturers, suppliers, and distributors with professional buyers, 
		healthcare practitioners, and procurement decision-makers across Asia-Pacific.
		
		Primary Function: Enable effective business-to-business connections through 
		structured exhibition spaces, targeted business matching services, educational 
		seminars, and product demonstrations, ultimately driving trade relationships 
		and market expansion in the medical and healthcare sector.
		*/
		
		perform action fairOperations : ConductFair {
			in fairDuration = 72.0;
			in maxExhibitors = 300;
			in maxVisitors = 5000;
		}
		
		part exhibitionHalls : ExhibitionHall[3] {
			attribute totalArea = 12000.0;
			attribute capacity = 300;
			perform fairOperations.preparationPhase.allocateBooths;
		}
		
		part registrationCenter : RegistrationCenter {
			attribute totalExhibitorsRegistered = 0;
			attribute totalVisitorsRegistered = 0;
			perform fairOperations.preparationPhase.processExhibitorRegistrations;
			perform fairOperations.operationalPhase.processVisitorRegistrations;
		}
		
		part eventCoordination : EventCoordination {
			perform fairOperations.preparationPhase.scheduleSeminars;
			perform fairOperations.operationalPhase.conductEvents;
		}
		
		part businessMatchingCenter : BusinessMatchingCenter {
			attribute activeMatches = 0;
			attribute meetingsScheduled = 0;
			perform fairOperations.operationalPhase.facilitateInteractions.matchPartners;
		}
		
		part informationDesks : InformationDesk[5] {
			perform fairOperations.operationalPhase.facilitateInteractions.provideInformation;
		}
		
		connection exhibitorToRegistration
			connect exhibitors.registration to registrationCenter.exhibitorRegistration;
		
		connection visitorToRegistration
			connect visitors.registration to registrationCenter.visitorRegistration;
		
		connection exhibitorToMatching
			connect exhibitors.matchingService to businessMatchingCenter.exhibitorMatching;
		
		connection visitorToMatching
			connect visitors.matchingService to businessMatchingCenter.visitorMatching;
		
		connection visitorToInformation
			connect visitors.informationAccess to informationDesks.informationService;
		
		connection eventScheduling
			connect eventCoordination.scheduling to eventCoordination.seminars.scheduling;
	}
	
	requirement def ExhibitorEngagementRequirement {
		doc /* 
		Each exhibitor shall achieve meaningful engagement with qualified visitors 
		to justify participation investment.
		*/
		
		subject exhibitor : Exhibitor;
		
		require constraint minimumLeads {
			doc /* Each exhibitor shall generate minimum 40 qualified business leads. */
		}
		
		require constraint visitorQuality {
			doc /* At least 60% of visitor interactions shall be with decision-makers. */
		}
	}
	
	requirement def VisitorExperienceRequirement {
		doc /* 
		Visitors shall receive efficient, personalized support to maximize 
		their fair experience and business outcomes.
		*/
		
		subject visitor : Visitor;
		
		require constraint responseTime {
			doc /* Information desk queries shall be answered within 2 minutes. */
		}
		
		require constraint matchingAccuracy {
			doc /* Business matching recommendations shall have 75% relevance rating. */
		}
	}
	
	requirement def BusinessOutcomeRequirement {
		doc /* 
		The fair shall demonstrate measurable business value for all stakeholders.
		*/
		
		require constraint exhibitorROI {
			doc /* 70% of exhibitors shall report positive return on investment. */
		}
		
		require constraint dealValue {
			doc /* Fair shall facilitate minimum USD 50 million in projected deal value. */
		}
	}
	
	requirement def OperationalRequirement {
		doc /* 
		Fair operations shall meet efficiency and capacity targets.
		*/
		
		require constraint registrationEfficiency {
			doc /* Exhibitor registration processing shall complete within 24 hours. */
		}
		
		require constraint visitorProcessing {
			doc /* On-site visitor registration shall complete within 5 minutes. */
		}
		
		require constraint capacityUtilization {
			doc /* Exhibition space utilization shall exceed 85%. */
		}
	}
	
	requirement def FairEffectivenessRequirement {
		doc /* 
		The fair system shall effectively facilitate business connections and 
		knowledge transfer in the medical and healthcare sector.
		*/
		
		subject fairSystem : MedicalHealthcareFairSystem;
		
		require exhibitorEngagement : ExhibitorEngagementRequirement;
		require visitorSatisfaction : VisitorExperienceRequirement;
		require businessOutcomes : BusinessOutcomeRequirement;
		require operationalExcellence : OperationalRequirement;
	}
	
	requirement fairMissionRequirement : FairEffectivenessRequirement {
		doc /* 
		Top-level requirement ensuring the Hong Kong International Medical and 
		Healthcare Fair achieves its mission of advancing healthcare trade and innovation.
		*/
		
		assume constraint legitimateParticipants {
			doc /* All participants represent bona fide medical and healthcare organizations. */
		}
		
		assume constraint adequateInfrastructure {
			doc /* Venue facilities support all planned exhibition and event activities. */
		}
		
		assume constraint regulatoryCompliance {
			doc /* All exhibited products comply with relevant healthcare regulations. */
		}
	}
}
