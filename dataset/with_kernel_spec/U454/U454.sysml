package WingedInfusionSetSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;
    private import SI::mL;
    private import SI::m;
    private import SI::kg;

    package Definitions {
        item def PhysiologicalFluid {
            attribute volume : Real;
        }
        item def Saline :> PhysiologicalFluid;
        item def Medication :> PhysiologicalFluid;
        item def BloodSample :> PhysiologicalFluid;

        port def FluidPort {
            out item fluid : PhysiologicalFluid;
        }

        part def Needle {
            attribute gauge : Real;
            attribute length : Real;
            attribute bevelAngle : Real;
            attribute isSterile : Boolean;
            attribute isSharp : Boolean;
            port fluidInPort : ~FluidPort;
            port patientPort : FluidPort;
        }

        part def Wing {
            attribute material : String;
            attribute length : Real;
            attribute width : Real;
            attribute isTaped : Boolean;
        }

        part def Tube {
            attribute innerDiameter : Real;
            attribute length : Real;
            attribute material : String;
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
        }

        part def SafetyClamp {
            attribute isClosed : Boolean;
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
        }

        part def FlowRegulator {
            attribute rollerPosition : Real;
            attribute maxFlowRate : Real;
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
        }

        part def LuerLockConnector {
            attribute isConnected : Boolean;
            attribute isLeakProof : Boolean;
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
        }

        part def IVBag {
            attribute capacity : Real;
            attribute currentVolume : Real;
            port outletPort : FluidPort;
        }

        part def Patient {
            attribute identifier : String;
            attribute veinAccessed : Boolean;
            port veinPort : ~FluidPort;
        }

        part def WingedInfusionSet {
            attribute isSterile : Boolean;
            attribute isSingleUse : Boolean;
            attribute isDisposed : Boolean;
            part needle : Needle;
            part wings : Wing[2];
            part tubing : Tube;
            part safetyClamp : SafetyClamp;
            part flowRegulator : FlowRegulator;
            part luerLock : LuerLockConnector;
            flow of fluid : PhysiologicalFluid from luerLock.outletPort.fluid to flowRegulator.inletPort.fluid;
            flow of fluid : PhysiologicalFluid from flowRegulator.outletPort.fluid to safetyClamp.inletPort.fluid;
            flow of fluid : PhysiologicalFluid from safetyClamp.outletPort.fluid to tubing.inletPort.fluid;
            flow of fluid : PhysiologicalFluid from tubing.outletPort.fluid to needle.fluidInPort.fluid;
        }

        action def PreparePatient {
            in patient : Patient;
            out prepared : Boolean;
        }
        action def InsertNeedle {
            in needle : Needle;
            in patient : Patient;
            out inserted : Boolean;
        }
        action def SecureWings {
            in wings : Wing[2];
            out secured : Boolean;
        }
        action def ConnectIVLine {
            in luerLock : LuerLockConnector;
            in ivBag : IVBag;
            out connected : Boolean;
        }
        action def SetFlowRate {
            in flowRegulator : FlowRegulator;
            in desiredRate : Real;
            out rateSet : Boolean;
        }
        action def InfuseFluid {
            in ivBag : IVBag;
            in flowRegulator : FlowRegulator;
            in patient : Patient;
            out infusedVolume : Real;
        }
        action def PauseInfusion {
            in safetyClamp : SafetyClamp;
            out paused : Boolean;
        }
        action def ResumeInfusion {
            in safetyClamp : SafetyClamp;
            in flowRegulator : FlowRegulator;
            out resumed : Boolean;
        }
        action def RemoveNeedle {
            in needle : Needle;
            in patient : Patient;
            out removed : Boolean;
        }
        action def DisposeDevice {
            in infusionSet : WingedInfusionSet;
            out disposed : Boolean;
        }
        action def DrawBlood {
            in needle : Needle;
            in patient : Patient;
            out sample : BloodSample;
        }
    }

    public import Definitions::Needle;
    public import Definitions::WingedInfusionSet;
    public import Definitions::Patient;
    public import Definitions::IVBag;

    package Usages {
        private import Definitions::*;

        part def ButterflyNeedleSystem {
            part infusionSet : WingedInfusionSet;
            part ivBag : IVBag;
            part patient : Patient;
            flow of fluid : PhysiologicalFluid
                from ivBag.outletPort.fluid
                to infusionSet.luerLock.inletPort.fluid;
            flow of fluid : PhysiologicalFluid
                from infusionSet.needle.patientPort.fluid
                to patient.veinPort.fluid;
            perform action infuseFluid : InfuseFluid {
                in ivBag = ivBag;
                in flowRegulator = infusionSet.flowRegulator;
                in patient = patient;
                out infusedVolume;
            }
        }

        state def WingedInfusionSetLifecycle {
            entry;
                then packaged;
            state packaged {
                entry;
                    /* Device is sterile and sealed in packaging */
            }
            transition packaged_to_prepared
                first packaged
                accept PreparePatient
                then prepared;
            state prepared {
                entry;
                    /* Patient skin prepped, device removed from sterile packaging */
            }
            transition prepared_to_inserted
                first prepared
                accept InsertNeedle
                then inserted;
            state inserted {
                entry;
                    /* Needle has entered the peripheral vein */
            }
            transition inserted_to_secured
                first inserted
                accept SecureWings
                then secured;
            state secured {
                entry;
                    /* Wings are taped flat against skin, needle stabilized */
            }
            transition secured_to_connected
                first secured
                accept ConnectIVLine
                then connected;
            state connected {
                entry;
                    /* Luer lock connected to IV line from reservoir */
            }
            transition connected_to_infusing
                first connected
                accept SetFlowRate
                then infusing;
            state infusing {
                entry;
                    /* Fluid is actively being delivered at the set flow rate */
            }
            transition infusing_to_paused
                first infusing
                accept PauseInfusion
                then paused;
            state paused {
                entry;
                    /* Safety clamp closed, flow completely stopped */
            }
            transition paused_to_infusing
                first paused
                accept ResumeInfusion
                then infusing;
            transition infusing_to_removed
                first infusing
                accept RemoveNeedle
                then removed;
            transition paused_to_removed
                first paused
                accept RemoveNeedle
                then removed;
            state removed {
                entry;
                    /* Needle withdrawn from patient, device no longer in use */
            }
            transition removed_to_disposed
                first removed
                accept DisposeDevice
                then disposed;
            state disposed {
                entry;
                    /* Device placed in sharps container for safe disposal */
            }
            transition disposed_to_done
                first disposed
                accept DisposeDevice
                then done;
        }
    }

    public import Usages::WingedInfusionSetLifecycle;

    package Requirements {
        private import Definitions::*;

        requirement def SterilityRequirement {
            doc /* The winged infusion set must be sterile and single-use. */
            subject infusionSet : WingedInfusionSet;
            constraint { infusionSet.isSterile == true }
            constraint { infusionSet.isSingleUse == true }
        }
        requirement def NeedleSharpnessRequirement {
            doc /* The needle must be beveled and sharp for smooth venipuncture. */
            subject needle : Needle;
            constraint { needle.isSharp == true }
            constraint { needle.bevelAngle > 0.0 }
        }
        requirement def FlowControlRequirement {
            doc /* The system must allow both complete shutoff and fine flow adjustment. */
            subject infusionSet : WingedInfusionSet;
            constraint { infusionSet.safetyClamp.isClosed == true or infusionSet.flowRegulator.rollerPosition >= 0.0 }
            constraint { infusionSet.flowRegulator.maxFlowRate > 0.0 }
        }
        requirement def LeakProofConnectionRequirement {
            doc /* The luer lock connector must provide a secure, leak-proof connection. */
            subject luerLock : LuerLockConnector;
            constraint { luerLock.isLeakProof == true }
            constraint { luerLock.isConnected == true }
        }
        requirement def WingStabilizationRequirement {
            doc /* The wings must provide ergonomic grip and lie flat for taping. */
            subject wings : Wing[2];
        }
        requirement def DeliveryVolumeRequirement {
            doc /* The system must deliver a specified volume of fluid over a period. */
            subject ivBag : IVBag;
            constraint { ivBag.capacity > 0.0 }
            constraint { ivBag.currentVolume <= ivBag.capacity }
        }
        requirement def SafeRemovalRequirement {
            doc /* The device must be safely removable after treatment or sample collection. */
            subject infusionSet : WingedInfusionSet;
            constraint { infusionSet.isDisposed == true }
        }
    }

    package VerificationCases {
        private import Definitions::*;
        private import Requirements::*;

        verification case def SterilityVerificationCase {
            subject infusionSet : WingedInfusionSet;
            objective { doc /* Verify sterility and single-use requirement. */ }
        }
        verification case def NeedleSharpnessVerificationCase {
            subject needle : Needle;
            objective { doc /* Verify needle sharpness and bevel angle. */ }
        }
        verification case def FlowControlVerificationCase {
            subject infusionSet : WingedInfusionSet;
            objective { doc /* Verify flow control capability. */ }
        }
        verification case def LeakProofVerificationCase {
            subject luerLock : LuerLockConnector;
            objective { doc /* Verify leak-proof connection. */ }
        }
        verification case def DeliveryVolumeVerificationCase {
            subject ivBag : IVBag;
            objective { doc /* Verify delivery volume constraints. */ }
        }

        verification verifySterility : SterilityVerificationCase {
            subject testInfusionSet : WingedInfusionSet;
        }
        verification verifyNeedleSharpness : NeedleSharpnessVerificationCase {
            subject testNeedle : Needle;
        }
        verification verifyFlowControl : FlowControlVerificationCase {
            subject testInfusionSet : WingedInfusionSet;
        }
        verification verifyLeakProof : LeakProofVerificationCase {
            subject testLuerLock : LuerLockConnector;
        }
        verification verifyDeliveryVolume : DeliveryVolumeVerificationCase {
            subject testIVBag : IVBag;
        }
    }

    package LifecycleExample {
        private import Definitions::*;

        individual def SterileButterflyNeedle :> WingedInfusionSet;
        individual def PatientJohn :> Patient;
        individual def SalineBag500 :> IVBag;

        individual butterflySystem : SterileButterflyNeedle {
            timeslice preparation {
                :>> isSterile = true;
                :>> isSingleUse = true;
                part :>> needle {
                    :>> gauge = 21.0;
                    :>> isSharp = true;
                }
            }
            then timeslice insertion {
                part :>> needle {
                    /* Needle inserted into patient's peripheral vein */
                }
                part :>> wings {
                    :>> isTaped = true;
                }
            }
            then timeslice activeInfusion {
                part :>> luerLock {
                    :>> isConnected = true;
                }
                part :>> flowRegulator {
                    :>> rollerPosition = 0.6;
                }
                part :>> safetyClamp {
                    :>> isClosed = false;
                }
            }
            then timeslice pausedInfusion {
                part :>> safetyClamp {
                    :>> isClosed = true;
                }
                part :>> flowRegulator {
                    :>> rollerPosition = 0.0;
                }
            }
            then timeslice removal {
                part :>> needle {
                    /* Needle withdrawn */
                }
                :>> isDisposed = false;
            }
            then timeslice disposal {
                :>> isDisposed = true;
            }
        }
    }
}
