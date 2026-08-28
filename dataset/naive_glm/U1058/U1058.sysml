package TransmutationSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value type MassNumber > Integer {
        doc /* Total nucleon count (protons + neutrons) */
    }

    value type ProtonCount > Integer {
        doc /* Atomic number Z */
    }

    value type NeutronCount > Integer {
        doc /* Neutron number N */
    }

    value type EnergyDensity > Real {
        ref attribute unit : EnergyDensityUnit[1] default 'J/m^3';
    }

    value type EnergyDensityUnit :> DerivedUnit {
        private ref attribute joulePerCubicMetre : Unit[1] = 'J/m^3';
    }

    value type RadiationLevel > Real {
        ref attribute unit : RadiationLevelUnit[1] default 'Sv/h';
    }

    value type RadiationLevelUnit :> DerivedUnit {
        private ref attribute sievertPerHour : Unit[1] = 'Sv/h';
    }

    value type ShieldingThickness > Length {
        ref attribute unit : LengthUnit[1] default 'm';
    }

    value type PowerOutput > Real {
        ref attribute unit : PowerOutputUnit[1] default 'MW';
    }

    value type PowerOutputUnit :> DerivedUnit {
        private ref attribute megawatt : Unit[1] = 'MW';
    }

    value type FieldIntensity > Real {
        ref attribute unit : FieldIntensityUnit[1] default 'PW/m^2';
    }

    value type FieldIntensityUnit :> DerivedUnit {
        private ref attribute petawattPerSquareMetre : Unit[1] = 'PW/m^2';
    }

    value type Confidence > Real {
        doc /* Fractional confidence 0.0 to 1.0 */
    }

    // ===== Item Types =====

    item def Nucleus {
        attribute protonCount : ProtonCount;
        attribute neutronCount : NeutronCount;
        derived attribute massNumber : MassNumber = protonCount + neutronCount;
    }

    item def Element {
        attribute symbol : String;
        attribute name : String;
        attribute atomicNumber : ProtonCount;
        ref attribute nucleus : Nucleus[1];
    }

    item def SourceMaterial {
        ref attribute element : Element[1];
        attribute quantity : Mass;
    }

    item def TransmutedMaterial {
        ref attribute element : Element[1];
        attribute quantity : Mass;
        attribute purity : Real;
    }

    item def ScanResult {
        ref attribute sourceElement : Element[1];
        attribute detectedProtons : ProtonCount;
        attribute detectedNeutrons : NeutronCount;
        attribute confidence : Confidence;
    }

    item def TransmutationPlan {
        ref attribute sourceElement : Element[1];
        ref attribute targetElement : Element[1];
        attribute protonsToAdd : ProtonCount default 0;
        attribute protonsToRemove : ProtonCount default 0;
        attribute neutronsToAdd : NeutronCount default 0;
        attribute neutronsToRemove : NeutronCount default 0;
        attribute estimatedEnergy : Energy;
        attribute stepCount : Integer;
    }

    item def VerificationReport {
        ref attribute targetElement : Element[1];
        attribute measuredProtons : ProtonCount;
        attribute measuredNeutrons : NeutronCount;
        attribute matchAchieved : Boolean;
        attribute residualRadiation : RadiationLevel;
    }

    item def NucleonStream {
        attribute nucleonType : String; // "proton" or "neutron"
        attribute count : Integer;
        attribute kineticEnergy : Energy;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute payload : String;
    }

    item def StatusReport {
        attribute currentState : String;
        attribute progress : Real;
        attribute safeOperation : Boolean;
    }

    // ===== Port Definitions =====

    port def ScanResultPort {
        out scanResult : ScanResult;
    }

    port def PlanPort {
        out plan : TransmutationPlan;
        in planAck : Boolean;
    }

    port def CommandPort {
        in command : ControlCommand;
        out status : StatusReport;
    }

    port def FieldPort {
        out fieldIntensity : FieldIntensity;
    }

    port def NucleonPort {
        in nucleonStream : NucleonStream;
    }

    port def MaterialPort {
        in source : SourceMaterial;
        out transmuted : TransmutedMaterial;
    }

    port def VerificationPort {
        in report : VerificationReport;
    }

    port def PowerPort {
        out power : PowerOutput;
    }

    // ===== Interfaces =====

    interface def ScanInterface {
        end scanner : ScanResultPort;
        end controller : ScanResultPort;
    }

    interface def PlanInterface {
        end controller : PlanPort;
        end manipulator : PlanPort;
    }

    interface def FieldInterface {
        end generator : FieldPort;
        end manipulator : FieldPort;
    }

    interface def NucleonInterface {
        end manipulator : NucleonPort;
        end chamber : NucleonPort;
    }

    interface def MaterialInterface {
        end chamber : MaterialPort;
        end external : MaterialPort;
    }

    interface def PowerInterface {
        end source : PowerPort;
        end consumer : PowerPort;
    }

    interface def VerificationInterface {
        end scanner : VerificationPort;
        end controller : VerificationPort;
    }

    interface def CommandInterface {
        end interface_ : CommandPort;
        end controller : CommandPort;
    }

    // ===== Requirements =====

    requirement def TransmutationRequirement {
        doc /* The system shall transmute a source element into a target element by adjusting nucleon counts. */
        subject transmutationSystem : TransmutationSystem;
        requirement sourceMaterialProvided : SourceMaterial;
        requirement targetElementSpecified : Element;
        requirement achievedProtonCount : ProtonCount = targetElementSpecified.atomicNumber;
        requirement achievedNeutronCount : NeutronCount = targetElementSpecified.nucleus.neutronCount;
    }

    requirement def SafetyRequirement {
        doc /* The system shall contain all radiation within the containment chamber. */
        subject containmentChamber : ContainmentChamber;
        attribute maxExternalRadiation : RadiationLevel = 0.001 [Sv/h];
        requirement shieldingThickness : ShieldingThickness >= 2.0 [m];
    }

    requirement def ScanAccuracyRequirement {
        doc /* The nuclear scanner shall determine proton and neutron counts with at least 99.9% confidence. */
        subject nuclearScanner : NuclearScanner;
        attribute minConfidence : Confidence = 0.999;
    }

    requirement def FieldControlRequirement {
        doc /* The femtofield generator shall produce a field intensity sufficient for nucleon manipulation. */
        subject femtoFieldGenerator : FemtoFieldGenerator;
        attribute minFieldIntensity : FieldIntensity = 1.0 [PW/m^2];
    }

    requirement def PowerRequirement {
        doc /* The power source shall supply sufficient power for all high-energy components. */
        subject powerSource : PowerSource;
        attribute minPowerOutput : PowerOutput = 50.0 [MW];
    }

    // ===== Parts =====

    part def ContainmentChamber {
        doc /* Heavily shielded chamber where transmutation occurs. */
        attribute shieldingThickness : ShieldingThickness = 3.0 [m];
        attribute internalRadiationLimit : RadiationLevel = 1000.0 [Sv/h];
        attribute externalRadiationLimit : RadiationLevel = 0.001 [Sv/h];

        port materialPort : MaterialPort;
        port nucleonInPort : NucleonPort;

        part shieldingStructure {
            attribute material : String = "tungsten-boron composite";
            attribute layers : Integer = 5;
        }

        part sampleHolder {
            attribute capacity : Mass = 1.0 [kg];
            ref attribute heldMaterial : SourceMaterial[0..1];
        }

        part radiationMonitor {
            attribute currentLevel : RadiationLevel;
            action monitorRadiation {
                in chamberLevel : RadiationLevel;
                out alert : Boolean;
            }
        }

        state chamberBehavior {
            entry; then Empty;
            state Empty;
            state Loaded;
            state Active;
            state Secured;
            transition from Empty to Loaded when materialPort.source received;
            transition from Loaded to Active when nucleonInPort.nucleonStream received;
            transition from Active to Secured when radiationMonitor.currentLevel < externalRadiationLimit;
            transition from Secured to Empty when materialPort.transmuted sent;
        }
    }

    part def NuclearScanner {
        doc /* Analyzes source material to determine exact atomic composition. */
        attribute scanResolution : Real = 1e-15 [m];
        attribute scanDuration : Time = 5.0 [s];
        attribute confidence : Confidence = 0.9995;

        port scanResultPort : ScanResultPort;
        port verificationPort : VerificationPort;

        action performScan {
            in material : SourceMaterial;
            out result : ScanResult;
        }

        action performVerificationScan {
            in material : TransmutedMaterial;
            out report : VerificationReport;
        }

        state scannerBehavior {
            entry; then Standby;
            state Standby;
            state Scanning;
            state Verifying;
            state Reporting;
            transition from Standby to Scanning when scanRequested;
            transition from Scanning to Reporting when performScan.done;
            transition from Reporting to Standby when scanResultPort.scanResult sent;
            transition from Standby to Verifying when verifyRequested;
            transition from Verifying to Reporting when performVerificationScan.done;
            transition from Reporting to Standby when verificationPort.report sent;
        }
    }

    part def ProcessController {
        doc /* Central controller that plans and coordinates the transmutation process. */
        attribute clockSpeed : Real = 3.0e9 [Hz];
        attribute memoryCapacity : Real = 256.0 [GB];
        ref attribute targetElement : Element[1];

        port scanResultPort : ScanResultPort;
        port planPort : PlanPort;
        port commandPort : CommandPort;
        port verificationPort : VerificationPort;

        action analyzeScan {
            in scanResult : ScanResult;
            out analysis : ScanResult;
        }

        action createPlan {
            in sourceElement : Element;
            in targetElement : Element;
            out plan : TransmutationPlan;
        }

        action evaluateVerification {
            in report : VerificationReport;
            out success : Boolean;
        }

        state controllerBehavior {
            entry; then Idle;
            state Idle {
                entry;
            }
            state Scanning {
                entry;
            }
            state Planning {
                entry;
            }
            state Executing {
                entry;
            }
            state Verifying {
                entry;
            }
            state Complete {
                entry;
            }
            state Fault {
                entry;
            }
            transition from Idle to Scanning when scanResultPort.scanResult received;
            transition from Scanning to Planning when analyzeScan.done;
            transition from Planning to Executing when planPort.planAck received;
            transition from Executing to Verifying when verificationPort.report received;
            transition from Verifying to Complete when evaluateVerification.success == true;
            transition from Verifying to Executing when evaluateVerification.success == false;
            transition from Complete to Idle when commandPort.status sent;
            transition from any to Fault when commandPort.command.commandType == "abort";
            transition from Fault to Idle when commandPort.command.commandType == "reset";
        }
    }

    part def FemtoFieldGenerator {
        doc /* Generates a highly focused intense energy field within the chamber. */
        attribute maxFieldIntensity : FieldIntensity = 5.0 [PW/m^2];
        attribute focusPrecision : Real = 1e-16 [m];
        attribute warmupTime : Time = 2.0 [s];
        attribute powerDraw : PowerOutput = 30.0 [MW];

        port fieldPort : FieldPort;
        port powerPort : PowerPort;

        action generateField {
            in intensity : FieldIntensity;
            out field : FieldIntensity;
        }

        state generatorBehavior {
            entry; then Off;
            state Off;
            state Warming;
            state Active;
            state Cooling;
            transition from Off to Warming when activateRequested;
            transition from Warming to Active when warmupTime elapsed;
            transition from Active to Cooling when deactivateRequested;
            transition from Cooling to Off when temperatureStable;
        }
    }

    part def NucleonManipulator {
        doc /* Directs femtofield energy to add or remove protons and neutrons. */
        attribute manipulationPrecision : Real = 1e-17 [m];
        attribute maxNucleonsPerCycle : Integer = 10;
        attribute cycleTime : Time = 0.5 [s];

        port planPort : PlanPort;
        port fieldPort : FieldPort;
        port nucleonPort : NucleonPort;

        action executePlan {
            in plan : TransmutationPlan;
            in field : FieldIntensity;
            out stream : NucleonStream;
        }

        action addProtons {
            in count : ProtonCount;
            in field : FieldIntensity;
            out stream : NucleonStream;
        }

        action removeProtons {
            in count : ProtonCount;
            in field : FieldIntensity;
            out stream : NucleonStream;
        }

        action addNeutrons {
            in count : NeutronCount;
            in field : FieldIntensity;
            out stream : NucleonStream;
        }

        action removeNeutrons {
            in count : NeutronCount;
            in field : FieldIntensity;
            out stream : NucleonStream;
        }

        state manipulatorBehavior {
            entry; then Ready;
            state Ready;
            state ReceivingPlan;
            state Executing;
            state Emitting;
            state Done;
            transition from Ready to ReceivingPlan when planPort.plan received;
            transition from ReceivingPlan to Executing when planPort.planAck sent;
            transition from Executing to Emitting when executePlan.stream produced;
            transition from Emitting to Executing when cycleTime elapsed and plan.stepCount > 0;
            transition from Emitting to Done when plan.stepCount == 0;
            transition from Done to Ready when nucleonPort.nucleonStream sent;
        }
    }

    part def ControlInterface {
        doc /* Central control interface for operator management. */
        attribute displayType : String = "holographic";
        attribute inputMethod : String = "voice + tactile";

        port commandPort : CommandPort;

        action receiveOperatorInput {
            out command : ControlCommand;
        }

        action displayStatus {
            in status : StatusReport;
        }
    }

    part def PowerSource {
        doc /* Provides power to high-energy components. */
        attribute ratedOutput : PowerOutput = 75.0 [MW];
        attribute fuelType : String = "fusion cell";
        attribute runtime : Time = 3600.0 [s];

        port powerPort : PowerPort;

        state powerBehavior {
            entry; then Deactivated;
            state Deactivated;
            state Activated;
            state Overloaded;
            transition from Deactivated to Activated when startRequested;
            transition from Activated to Deactivated when stopRequested;
            transition from Activated to Overloaded when load > ratedOutput;
            transition from Overloaded to Deactivated when emergencyShutdown;
        }
    }

    // ===== Top-Level System =====

    part def TransmutationSystem {
        doc /* Femtotechnology system for controlled transmutation of chemical elements. */

        attribute systemId : String;
        attribute firmwareVersion : String = "2.1.0";

        part containmentChamber : ContainmentChamber;
        part nuclearScanner : NuclearScanner;
        part processController : ProcessController;
        part femtoFieldGenerator : FemtoFieldGenerator;
        part nucleonManipulator : NucleonManipulator;
        part controlInterface : ControlInterface;
        part powerSource : PowerSource;

        // Predefined elements for lead-to-gold transmutation
        item leadElement : Element {
            attribute symbol = "Pb";
            attribute name = "Lead";
            attribute atomicNumber = 82;
            ref nucleus : Nucleus {
                attribute protonCount = 82;
                attribute neutronCount = 125;
            }
        }

        item goldElement : Element {
            attribute symbol = "Au";
            attribute name = "Gold";
            attribute atomicNumber = 79;
            ref nucleus : Nucleus {
                attribute protonCount = 79;
                attribute neutronCount = 118;
            }
        }

        // Connections
        connection scanInterface : ScanInterface connect nuclearScanner.scanResultPort to processController.scanResultPort;

        connection planInterface : PlanInterface connect processController.planPort to nucleonManipulator.planPort;

        connection fieldInterface : FieldInterface connect femtoFieldGenerator.fieldPort to nucleonManipulator.fieldPort;

        connection nucleonInterface : NucleonInterface connect nucleonManipulator.nucleonPort to containmentChamber.nucleonInPort;

        connection materialInterface : MaterialInterface connect containmentChamber.materialPort to /* external loading bay */ containmentChamber.materialPort;

        connection verificationInterface : VerificationInterface connect nuclearScanner.verificationPort to processController.verificationPort;

        connection commandInterface : CommandInterface connect controlInterface.commandPort to processController.commandPort;

        connection powerToGenerator : PowerInterface connect powerSource.powerPort to femtoFieldGenerator.powerPort;

        // System-level state machine
        state systemOperation {
            entry; then Idle;
            state Idle {
                doc /* System powered but not actively transmuting. */
                entry;
            }
            state Scanning {
                doc /* Nuclear scanner analyzing source material. */
                entry;
            }
            state Planning {
                doc /* Controller creating transmutation plan. */
                entry;
            }
            state Executing {
                doc /* Nucleon manipulator performing sub-atomic surgery. */
                entry;
            }
            state Verifying {
                doc /* Scanner verifying transmuted material matches target. */
                entry;
            }
            state Complete {
                doc /* Process finished, material ready for retrieval. */
                entry;
            }
            state EmergencyShutdown {
                doc /* Safety condition triggered, system halting. */
                entry;
            }
            transition from Idle to Scanning when sourceMaterialLoaded;
            transition from Scanning to Planning when scanComplete;
            transition from Planning to Executing when planApproved;
            transition from Executing to Verifying when manipulationComplete;
            transition from Verifying to Complete when verificationPassed;
            transition from Verifying to Executing when verificationFailed;
            transition from Complete to Idle when materialRetrieved;
            transition from any to EmergencyShutdown when radiationBreachDetected;
            transition from EmergencyShutdown to Idle when systemReset;
        }

        // System-level action sequence
        action transmuteSequence {
            in source : SourceMaterial;
            in target : Element;
            out result : TransmutedMaterial;

            perform scan : nuclearScanner.performScan {
                in material = source;
                out result = scanOutput;
            }
            perform plan : processController.createPlan {
                in sourceElement = scanOutput.sourceElement;
                in targetElement = target;
                out plan = transmutationPlan;
            }
            perform generate : femtoFieldGenerator.generateField {
                in intensity = femtoFieldGenerator.maxFieldIntensity;
                out field = fieldOutput;
            }
            perform manipulate : nucleonManipulator.executePlan {
                in plan = transmutationPlan;
                in field = fieldOutput;
                out stream = nucleonOutput;
            }
            perform verify : nuclearScanner.performVerificationScan {
                in material = result;
                out report = verificationReport;
            }
        }

        // Requirement satisfactions
        satisfy SafetyRequirement by containmentChamber;
        satisfy ScanAccuracyRequirement by nuclearScanner;
        satisfy FieldControlRequirement by femtoFieldGenerator;
        satisfy PowerRequirement by powerSource;
        satisfy TransmutationRequirement by transmuteSequence;
    }

}
