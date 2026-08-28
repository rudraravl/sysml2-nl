package LAAO_System {
    public import Definitions::*;

    package Definitions {
        attribute def Diameter :> ISQ::LengthValue;
        attribute def OutwardForce :> ISQ::ForceValue;
        attribute def AnchorForce :> ISQ::ForceValue;
        attribute def LeakRate :> ISQ::VolumeFlowRateValue;
        attribute def CatheterLength :> ISQ::LengthValue;
        attribute def StabilityFlag;
        attribute def SealQualityValue;
        attribute def Modality;

        attribute def AdvanceSignal;
        attribute def DeploySignal;
        attribute def AnchorSignal;
        attribute def VerifySignal;
        attribute def ReleaseSignal;
        attribute def PositionReachedSignal;

        item def ImageData;
        item def LAAMeasurement {
            attribute ostiumDiameter : Diameter;
            attribute depth : Diameter;
        }
        item def MonitoringReport {
            attribute residualLeakRate : LeakRate;
            attribute deviceStable : StabilityFlag;
            attribute sealQuality : SealQualityValue;
        }

        port def VascularInterface;
        port def NavigationInterface;
        port def DeploymentInterface;
        port def ImagingInterface;
        port def MonitoringInterface;

        part def Patient;
        part def Heart;
        part def LeftAtrialAppendage;

        part def Physician {
            port imagingDisplay : ImagingInterface;
            port monitoringDisplay : MonitoringInterface;
            port catheterControl : NavigationInterface;
            port deploymentControl : DeploymentInterface;
        }

        state def OccluderLifecycle {
            entry; then stowed;
            state stowed;
            accept AdvanceSignal then advanced;
            state advanced;
            accept PositionReachedSignal then deployed;
            state deployed;
            accept AnchorSignal then anchored;
            state anchored;
            accept VerifySignal then verified;
            state verified;
            accept ReleaseSignal then released;
            state released;
        }

        part def OccluderDevice {
            attribute nominalDiameter : Diameter;
            attribute outwardForce : OutwardForce;
            attribute anchorForce : AnchorForce;
            port deliveryInterface : VascularInterface;
            state occluderLifecycle : OccluderLifecycle;
        }

        part def DeliveryCatheter {
            attribute length : CatheterLength;
            port proximalNavigation : NavigationInterface;
            port proximalDeployment : DeploymentInterface;
            port distalAttachment : VascularInterface;
            part stowedOccluder : OccluderDevice;
        }

        part def ImagingSystem {
            port imagingOutput : ImagingInterface;
            attribute modality : Modality;
        }

        part def MonitoringSystem {
            port monitoringOutput : MonitoringInterface;
            attribute leakThreshold : LeakRate;
        }

        action def MeasureLAA {
            in image : ImageData;
            out measurement : LAAMeasurement;
        }
        action def SelectDevice {
            in measurement : LAAMeasurement;
            out selectedDiameter : Diameter;
        }
        action def NavigateCatheter {
            in image : ImageData;
            out positionReached : PositionReachedSignal;
        }
        action def DeployOccluder {
            in selectedDiameter : Diameter;
            out expandedDiameter : Diameter;
            out appliedForce : OutwardForce;
        }
        action def AnchorOccluder {
            in appliedForce : OutwardForce;
            out anchorForce : AnchorForce;
        }
        action def VerifySealAction {
            in image : ImageData;
            in expandedDiameter : Diameter;
            out sealQuality : SealQualityValue;
            out residualLeakRate : LeakRate;
        }
        action def ReleaseOccluder {
            out releasedDevice : OccluderDevice;
        }
        action def MonitorPatient {
            in residualLeakRate : LeakRate;
            in sealQuality : SealQualityValue;
            out report : MonitoringReport;
        }
        action def PerformLAAOProcedure {
            in imageData : ImageData;
            out finalReport : MonitoringReport;
        }

        requirement def PreventStroke {
            subject patient : Patient;
        }
        requirement def SealIntegrity {
            attribute maxLeakRate : LeakRate;
        }
        requirement def AnchorStability {
            attribute minAnchorForce : AnchorForce;
        }
        requirement def ImagingGuidance {
            attribute resolution : Diameter;
        }
        requirement def MonitoringAccuracy {
            attribute detectionThreshold : LeakRate;
        }
    }

    package Usages {
        public import Definitions::*;

        part laaoSystem {
            part patient : Patient {
                part heart : Heart {
                    part laa : LeftAtrialAppendage;
                }
            }
            part physician : Physician;
            part occluder : OccluderDevice;
            part catheter : DeliveryCatheter;
            part imaging : ImagingSystem;
            part monitoring : MonitoringSystem;

            connect catheter.distalAttachment to occluder.deliveryInterface;
            connect imaging.imagingOutput to physician.imagingDisplay;
            connect monitoring.monitoringOutput to physician.monitoringDisplay;
            connect physician.catheterControl to catheter.proximalNavigation;
            connect physician.deploymentControl to catheter.proximalDeployment;

            perform action laaoProcedure : PerformLAAOProcedure {
                in imageData : ImageData;
                out finalReport : MonitoringReport;

                action measureLAA : MeasureLAA {
                    in image = laaoProcedure::imageData;
                }
                action selectDevice : SelectDevice;
                action navigate : NavigateCatheter {
                    in image = laaoProcedure::imageData;
                }
                action deploy : DeployOccluder;
                action anchor : AnchorOccluder;
                action verifySeal : VerifySealAction {
                    in image = laaoProcedure::imageData;
                }
                action release : ReleaseOccluder;
                action monitor : MonitorPatient;

                flow measureLAA.measurement to selectDevice.measurement;
                flow selectDevice.selectedDiameter to deploy.selectedDiameter;
                flow deploy.expandedDiameter to verifySeal.expandedDiameter;
                flow deploy.appliedForce to anchor.appliedForce;
                flow verifySeal.sealQuality to monitor.sealQuality;
                flow verifySeal.residualLeakRate to monitor.residualLeakRate;
                bind finalReport = monitor.report;

                succession s1 first measureLAA then selectDevice;
                succession s2 first selectDevice then navigate;
                succession s3 first navigate then deploy;
                succession s4 first deploy then anchor;
                succession s5 first anchor then verifySeal;
                succession s6 first verifySeal then release;
                succession s7 first release then monitor;
            }

            requirement preventStrokeReq : PreventStroke {
                subject = patient;
            }
            requirement sealIntegrityReq : SealIntegrity;
            requirement anchorStabilityReq : AnchorStability;
            requirement imagingGuidanceReq : ImagingGuidance;
            requirement monitoringAccuracyReq : MonitoringAccuracy;
        }
    }
}
