package WingedInfusionSetSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value type FlowRate :> Real { unit "mL/hr"; }
    value type Volume :> Real { unit "mL"; }
    value type Pressure :> Real { unit "mmHg"; }
    value type Length :> Real { unit "mm"; }
    value type Duration :> Real { unit "min"; }
    value type Gauge :> Integer;
    value type Angle :> Real { unit "deg"; }

    // ===== Item Types =====
    item def IVFluid;
    item def Saline :> IVFluid;
    item def Medication;
    item def Blood;
    item def FluidMedicationMixture :> IVFluid;

    // ===== Port Definitions =====
    port def FluidPort {
        inout item fluid : IVFluid;
    }

    // ===== Requirements =====
    requirement def SterilityRequirement {
        doc "The winged infusion set must remain sterile until the point of use.";
        attribute maxBioburden : Real = 0;
        constraint { bioburden <= maxBioburden }
    }

    requirement def LeakProofConnectionRequirement {
        doc "The luer lock connector must maintain a leak-proof seal under operating pressure.";
        attribute maxOperatingPressure : Pressure = 300 [mmHg];
        constraint { connectionPressure <= maxOperatingPressure }
    }

    requirement def FlowControlRequirement {
        doc "The flow regulator must allow fine-tuned adjustment of the fluid delivery rate.";
        attribute minFlowRate : FlowRate = 0 [mL/hr];
        attribute maxFlowRate : FlowRate = 250 [mL/hr];
        constraint { currentFlowRate >= minFlowRate and currentFlowRate <= maxFlowRate }
    }

    requirement def ErgonomicGripRequirement {
        doc "The wings must provide an ergonomic grip for precise needle control during insertion.";
        attribute minWingLength : Length = 20 [mm];
        attribute maxWingLength : Length = 30 [mm];
        constraint { wingLength >= minWingLength and wingLength <= maxWingLength }
    }

    requirement def SmoothEntryRequirement {
        doc "The needle must be beveled for smooth entry into a peripheral vein.";
        attribute bevelAngle : Angle = 30 [deg];
    }

    requirement def CompleteShutoffRequirement {
        doc "The safety clamp must completely stop fluid flow when engaged.";
        constraint { clampClosed implies currentFlowRate == 0 [mL/hr] }
    }

    requirement def SingleUseRequirement {
        doc "The device must be single-use and disposed after one patient.";
        attribute isReusable : Boolean = false;
        constraint { isReusable == false }
    }

    requirement def DeliveryVolumeRequirement {
        doc "The system must be capable of delivering a prescribed volume over a specified duration.";
        attribute minDeliverableVolume : Volume = 10 [mL];
        attribute maxDeliverableVolume : Volume = 1000 [mL];
        constraint { deliveredVolume >= minDeliverableVolume and deliveredVolume <= maxDeliverableVolume }
    }

    // ===== External Parts =====
    part def Patient {
        attribute peripheralVeinAccessible : Boolean = true;
        attribute skinPrepared : Boolean = false;
        attribute veinDepth : Length = 3 [mm];
        port veinPort : FluidPort;
    }

    part def FluidReservoir {
        attribute fluidType : String = "saline";
        attribute totalVolume : Volume = 500 [mL];
        attribute remainingVolume : Volume = 500 [mL];
        attribute hangingHeight : Length = 1000 [mm];
        port bagPort : FluidPort;
    }

    part def Clinician {
        attribute role : String = "registered nurse";
        attribute trained : Boolean = true;
        attribute gloved : Boolean = true;
    }

    part def SharpsContainer {
        attribute capacity : Volume = 1000 [mL];
        attribute isFull : Boolean = false;
        attribute sealed : Boolean = false;
    }

    // ===== Component Part Definitions =====
    part def Needle {
        attribute gauge : Gauge = 21;
        attribute length : Length = 19 [mm];
        attribute bevelAngle : Angle = 30 [deg];
        attribute material : String = "stainless steel";
        attribute isBeveled : Boolean = true;
        port tipPort : FluidPort;
        port basePort : FluidPort;
        connection needleFlow connect tipPort to basePort;
    }

    part def Wings {
        attribute material : String = "flexible plastic";
        attribute length : Length = 25 [mm];
        attribute width : Length = 12 [mm];
        attribute color : String = "blue";
        attribute isTaped : Boolean = false;
    }

    part def Tubing {
        attribute length : Length = 300 [mm];
        attribute material : String = "medical-grade PVC";
        attribute innerDiameter : Length = 3 [mm];
        attribute outerDiameter : Length = 4 [mm];
        port proximalPort : FluidPort;
        port distalPort : FluidPort;
        connection tubingFlow connect proximalPort to distalPort;
    }

    part def SafetyClamp {
        attribute isOpen : Boolean = true;
        attribute clampClosed : Boolean = false;
        attribute material : String = "rigid plastic";
        port inlinePort : FluidPort;
        port outlinePort : FluidPort;
        connection clampFlow connect inlinePort to outlinePort;

        state clampState {
            entry; then Open;
            state Open {
                doc "Clamp open, fluid flows freely.";
            }
            state Closed {
                doc "Clamp closed, fluid flow completely stopped.";
            }
            transition from Open to Closed when clampEngaged;
            transition from Closed to Open when clampReleased;
        }
    }

    part def FlowRegulator {
        attribute rollerPosition : Real = 0.0;
        attribute currentFlowRate : FlowRate = 0 [mL/hr];
        attribute maxFlowRate : FlowRate = 250 [mL/hr];
        attribute material : String = "rigid plastic";
        port inlinePort : FluidPort;
        port outlinePort : FluidPort;
        connection regulatorFlow connect inlinePort to outlinePort;
    }

    part def LuerLockConnector {
        attribute isLocked : Boolean = false;
        attribute connectorType : String = "standard luer lock";
        attribute material : String = "rigid plastic";
        port devicePort : FluidPort;
        port externalPort : FluidPort;
        connection connectorFlow connect devicePort to externalPort;
    }

    // ===== Action Definitions =====
    action def PreparePatient {
        doc "Prepare the patient's skin at the insertion site.";
        in patient : Patient;
        in clinician : Clinician;
        out skinPrepared : Boolean;
    }

    action def InsertNeedle {
        doc "Insert the beveled needle into the patient's peripheral vein.";
        in needle : Needle;
        in patient : Patient;
        in clinician : Clinician;
        out insertionSuccessful : Boolean;
    }

    action def SecureWings {
        doc "Tape the wings flat against the skin to stabilize the needle.";
        in leftWing : Wings;
        in rightWing : Wings;
        out secured : Boolean;
    }

    action def ConnectToReservoir {
        doc "Connect the luer lock to the fluid reservoir line.";
        in luerLock : LuerLockConnector;
        in reservoir : FluidReservoir;
        out connected : Boolean;
    }

    action def SetFlowRate {
        doc "Adjust the flow regulator to the desired delivery rate.";
        in flowRegulator : FlowRegulator;
        in desiredRate : FlowRate;
        out setRate : FlowRate;
    }

    action def PauseFlow {
        doc "Engage the safety clamp to stop flow.";
        in safetyClamp : SafetyClamp;
        out paused : Boolean;
    }

    action def ResumeFlow {
        doc "Release the safety clamp to resume flow.";
        in safetyClamp : SafetyClamp;
        out resumed : Boolean;
    }

    action def RemoveDevice {
        doc "Withdraw the needle from the patient and activate safety mechanism.";
        in needle : Needle;
        out removed : Boolean;
    }

    action def DisposeDevice {
        doc "Dispose of the used device in a sharps container.";
        in sharpsContainer : SharpsContainer;
        out disposed : Boolean;
    }

    action def CollectBloodSample {
        doc "Collect a blood sample through the tubing if required.";
        in tubing : Tubing;
        out sampleCollected : Boolean;
    }

    // ===== Procedure Composition =====
    action def InfusionProcedure {
        doc "Standard IV infusion procedure using the winged infusion set.";
        action preparePatient : PreparePatient;
        action insertNeedle : InsertNeedle;
        action secureWings : SecureWings;
        action connectToReservoir : ConnectToReservoir;
        action setFlowRate : SetFlowRate;
        action pauseFlow : PauseFlow;
        action resumeFlow : ResumeFlow;
        action removeDevice : RemoveDevice;
        action disposeDevice : DisposeDevice;

        succession first preparePatient then insertNeedle;
        succession insertNeedle then secureWings;
        succession secureWings then connectToReservoir;
        succession connectToReservoir then setFlowRate;
        succession setFlowRate then pauseFlow;
        succession pauseFlow then resumeFlow;
        succession resumeFlow then removeDevice;
        succession removeDevice then disposeDevice;
    }

    action def BloodDrawProcedure {
        doc "Blood collection procedure using the winged infusion set.";
        action preparePatient : PreparePatient;
        action insertNeedle : InsertNeedle;
        action secureWings : SecureWings;
        action collectSample : CollectBloodSample;
        action removeDevice : RemoveDevice;
        action disposeDevice : DisposeDevice;

        succession first preparePatient then insertNeedle;
        succession insertNeedle then secureWings;
        succession secureWings then collectSample;
        succession collectSample then removeDevice;
        succession removeDevice then disposeDevice;
    }

    // ===== Winged Infusion Set Composite =====
    part def WingedInfusionSet {
        attribute isSterile : Boolean = true;
        attribute isSingleUse : Boolean = true;
        attribute manufacturerId : String;
        attribute lotNumber : String;
        attribute expirationDate : String;
        attribute deliveredVolume : Volume = 0 [mL];
        attribute targetVolume : Volume = 500 [mL];
        attribute infusionDuration : Duration = 60 [min];

        // Lifecycle trigger attributes
        attribute packageOpened : Boolean = false;
        attribute needleInserted : Boolean = false;
        attribute wingsTaped : Boolean = false;
        attribute luerLocked : Boolean = false;
        attribute flowStarted : Boolean = false;
        attribute safetyClampClosed : Boolean = false;
        attribute safetyClampOpened : Boolean = false;
        attribute targetVolumeReached : Boolean = false;
        attribute removalInitiated : Boolean = false;
        attribute deviceDiscarded : Boolean = false;

        part needle : Needle;
        part leftWing : Wings;
        part rightWing : Wings;
        part tubing : Tubing;
        part safetyClamp : SafetyClamp;
        part flowRegulator : FlowRegulator;
        part luerLock : LuerLockConnector;

        port patientEndPort : FluidPort;
        port reservoirEndPort : FluidPort;

        // Internal connections forming the fluid pathway
        connection needleToTubing connect needle.basePort to tubing.proximalPort;
        connection tubingToSafetyClamp connect tubing.distalPort to safetyClamp.inlinePort;
        connection safetyClampToRegulator connect safetyClamp.outlinePort to flowRegulator.inlinePort;
        connection regulatorToLuer connect flowRegulator.outlinePort to luerLock.devicePort;

        // External port bindings
        connection patientEnd connect needle.tipPort to patientEndPort;
        connection reservoirEnd connect luerLock.externalPort to reservoirEndPort;

        // Lifecycle state machine
        state lifecycle {
            entry; then Packaged;

            state Packaged {
                doc "Device in sterile packaging, ready for use.";
            }

            state Prepared {
                doc "Patient skin prepared, device removed from packaging.";
            }

            state Inserted {
                doc "Needle inserted into patient's peripheral vein.";
            }

            state Secured {
                doc "Wings taped down, needle stabilized against skin.";
            }

            state Connected {
                doc "Luer lock connected to fluid reservoir line.";
            }

            state Infusing {
                doc "Fluid actively flowing at the set delivery rate.";
            }

            state Paused {
                doc "Flow stopped via safety clamp.";
            }

            state Completed {
                doc "Target volume delivered or blood sample collected.";
            }

            state Removed {
                doc "Needle withdrawn from patient.";
            }

            state Disposed {
                doc "Device disposed in sharps container.";
            }

            transition from Packaged to Prepared when packageOpened;
            transition from Prepared to Inserted when needleInserted;
            transition from Inserted to Secured when wingsTaped;
            transition from Secured to Connected when luerLocked;
            transition from Connected to Infusing when flowStarted;
            transition from Infusing to Paused when safetyClampClosed;
            transition from Paused to Infusing when safetyClampOpened;
            transition from Infusing to Completed when targetVolumeReached;
            transition from Completed to Removed when removalInitiated;
            transition from Paused to Removed when removalInitiated;
            transition from Removed to Disposed when deviceDiscarded;
        }
    }

    // ===== System Context =====
    part def WingedInfusionSetContext {
        doc "System context for the winged infusion set connecting a fluid reservoir to a patient.";

        part infusionSet : WingedInfusionSet;
        part patient : Patient;
        part reservoir : FluidReservoir;
        part clinician : Clinician;
        part sharpsContainer : SharpsContainer;

        // External connections
        connection patientConnection connect infusionSet.patientEndPort to patient.veinPort;
        connection reservoirConnection connect infusionSet.reservoirEndPort to reservoir.bagPort;

        // Requirement satisfaction
        satisfy SterilityRequirement by infusionSet;
        satisfy LeakProofConnectionRequirement by infusionSet.luerLock;
        satisfy FlowControlRequirement by infusionSet.flowRegulator;
        satisfy ErgonomicGripRequirement by infusionSet.leftWing;
        satisfy ErgonomicGripRequirement by infusionSet.rightWing;
        satisfy SmoothEntryRequirement by infusionSet.needle;
        satisfy CompleteShutoffRequirement by infusionSet.safetyClamp;
        satisfy SingleUseRequirement by infusionSet;
        satisfy DeliveryVolumeRequirement by infusionSet;
    }
}
