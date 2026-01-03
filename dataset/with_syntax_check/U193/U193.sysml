package CrashCartSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PatientVitals {
        attribute heartRate : Real;
        attribute bloodPressure : Real;
        attribute oxygenSaturation : Real;
        attribute respiratoryRate : Real;
        attribute ecgRhythm : String;
    }
    
    attribute def EmergencyStatus {
        attribute severityLevel : Integer;
        attribute responseRequired : Boolean;
        attribute timeElapsed : DurationValue;
    }
    
    item def EmergencyMedication {
        attribute medicationName : String;
        attribute concentration : Real;
        attribute volume : VolumeValue;
        attribute expirationDate : String;
    }
    
    item def Epinephrine :> EmergencyMedication {
        attribute :>> medicationName = "Epinephrine";
        attribute :>> concentration = 1.0;
    }
    
    item def Atropine :> EmergencyMedication {
        attribute :>> medicationName = "Atropine";
        attribute :>> concentration = 0.5;
    }
    
    item def Amiodarone :> EmergencyMedication {
        attribute :>> medicationName = "Amiodarone";
        attribute :>> concentration = 150.0;
    }
    
    port def MonitoringPort {
        in patientData : PatientVitals;
        out displayData : PatientVitals;
    }
    
    port def PowerPort {
        out voltage : ElectricPotentialValue;
        out current : ElectricCurrentValue;
    }
    
    port def DefibrillationPort {
        in chargeCommand : EnergyValue;
        out shockDelivered : Boolean;
    }
    
    port def OxygenDeliveryPort {
        in flowRateCommand : VolumeValue;
        out oxygenDelivering : Boolean;
    }
    
    part def Defibrillator {
        attribute maxEnergyCapacity : EnergyValue;
        attribute currentCharge : EnergyValue;
        attribute isCharged : Boolean;
        attribute shockCount : Integer;
        
        port defibPort : DefibrillationPort;
        port powerInput : PowerPort;
        
        action def ChargeDefibrillator {
            in targetEnergy : EnergyValue;
            in availablePower : PowerValue;
            out chargeReady : Boolean;
            out chargeLevel : EnergyValue;
        }
        
        action def DeliverShock {
            in energyLevel : EnergyValue;
            in rhythmShockable : Boolean;
            out shockSuccess : Boolean;
        }
    }
    
    part def CardiacMonitor {
        attribute displayActive : Boolean;
        attribute batteryLevel : Real;
        attribute alarmThresholds : PatientVitals;
        
        port monitorPort : MonitoringPort;
        port powerInput : PowerPort;
        
        action def MonitorPatient {
            out vitals : PatientVitals;
            out alarmTriggered : Boolean;
        }
        
        action def AnalyzeRhythm {
            in ecgData : String;
            out shockableRhythm : Boolean;
            out rhythmType : String;
        }
    }
    
    part def OxygenSystem {
        attribute tankPressure : PressureValue;
        attribute maxPressure : PressureValue;
        attribute currentFlowRate : VolumeValue;
        attribute regulatorSetting : Real;
        
        port oxygenPort : OxygenDeliveryPort;
        
        action def SupplyOxygen {
            in requestedFlowRate : VolumeValue;
            in tankPressure : PressureValue;
            out actualFlowRate : VolumeValue;
            out oxygenAvailable : Boolean;
        }
    }
    
    part def MedicationDrawer {
        attribute drawerNumber : Integer;
        attribute isLocked : Boolean;
        attribute inventoryComplete : Boolean;
        
        item epinephrineDoses : Epinephrine[10];
        item atropineDoses : Atropine[10];
        item amiodaroneDoses : Amiodarone[6];
        
        action def DispenseMedication {
            in medicationRequested : EmergencyMedication;
            out medicationAvailable : Boolean;
            out dispensedMedication : EmergencyMedication;
        }
    }
    
    part def AirwayEquipment {
        attribute endotrachealTubes : Integer;
        attribute bagValveMaskAvailable : Boolean;
        attribute suctionReady : Boolean;
        
        action def SecureAirway {
            in patientCondition : PatientVitals;
            out airwayEstablished : Boolean;
        }
    }
    
    part def PowerSupply {
        attribute batteryCapacity : EnergyValue;
        attribute batteryCharge : EnergyValue;
        attribute acPowerConnected : Boolean;
        attribute outputVoltage : ElectricPotentialValue;
        
        port mainPower : PowerPort;
        
        action def ProvidePower {
            in powerDemand : PowerValue;
            out powerAvailable : Boolean;
            out remainingCapacity : EnergyValue;
        }
    }
    
    action def EmergencyResuscitation {
        first start;
        then merge continueResuscitation;
        
        then action monitorVitals : CardiacMonitor.MonitorPatient {
            out currentVitals : PatientVitals;
            out alarm : Boolean;
        }
        
        then action analyzeCardiacRhythm : CardiacMonitor.AnalyzeRhythm {
            in ecgData = monitorVitals.currentVitals.ecgRhythm;
            out shockable : Boolean;
            out diagnosis : String;
        }
        
        then decide;
            if analyzeCardiacRhythm.shockable then defibrillationSequence;
            if not analyzeCardiacRhythm.shockable then medicationSequence;
        
        action defibrillationSequence {
            first parallel defibrillationActions;
            
            action parallel defibrillationActions {
                action chargeUnit : Defibrillator.ChargeDefibrillator {
                    in targetEnergy : EnergyValue;
                    in availablePower : PowerValue;
                    out chargeReady : Boolean;
                    out chargeLevel : EnergyValue;
                }
                
                action preparePatient;
            }
            
            then action deliverTherapy : Defibrillator.DeliverShock {
                in energyLevel = chargeUnit.chargeLevel;
                in rhythmShockable = analyzeCardiacRhythm.shockable;
                out shockSuccess : Boolean;
            }
            
            then action administerEpinephrine : MedicationDrawer.DispenseMedication {
                in medicationRequested : EmergencyMedication;
                out medicationAvailable : Boolean;
                out dispensedMedication : EmergencyMedication;
            }
        }
        then continueResuscitation;
        
        action medicationSequence {
            first action administerAtropine : MedicationDrawer.DispenseMedication {
                in medicationRequested : EmergencyMedication;
                out medicationAvailable : Boolean;
                out dispensedMedication : EmergencyMedication;
            }
            
            then action provideOxygen : OxygenSystem.SupplyOxygen {
                in requestedFlowRate : VolumeValue;
                in tankPressure : PressureValue;
                out actualFlowRate : VolumeValue;
                out oxygenAvailable : Boolean;
            }
        }
        then continueResuscitation;
        
        then decide;
            if monitorVitals.currentVitals.heartRate > 60.0 and 
               monitorVitals.currentVitals.oxygenSaturation > 90.0 then completeResuscitation;
            if monitorVitals.currentVitals.heartRate <= 60.0 or 
               monitorVitals.currentVitals.oxygenSaturation <= 90.0 then continueResuscitation;
        
        action completeResuscitation;
        then done;
    }
    
    part def CrashCart {
        attribute cartIdentifier : String;
        attribute locationAssigned : String;
        attribute lastInspectionDate : String;
        attribute operationalStatus : Boolean;
        attribute totalWeight : MassValue;
        
        part defibrillator : Defibrillator {
            attribute :>> maxEnergyCapacity = 360.0[J];
            attribute :>> currentCharge = 0.0[J];
            attribute :>> isCharged = false;
            attribute :>> shockCount = 0;
        }
        
        part monitor : CardiacMonitor {
            attribute :>> displayActive = true;
            attribute :>> batteryLevel = 100.0;
        }
        
        part oxygenSystem : OxygenSystem {
            attribute :>> tankPressure = 2000.0[kPa];
            attribute :>> maxPressure = 2200.0[kPa];
            attribute :>> currentFlowRate = 0.0[L];
            attribute :>> regulatorSetting = 0.0;
        }
        
        part topDrawer : MedicationDrawer {
            attribute :>> drawerNumber = 1;
            attribute :>> isLocked = false;
            attribute :>> inventoryComplete = true;
        }
        
        part airwayKit : AirwayEquipment {
            attribute :>> endotrachealTubes = 12;
            attribute :>> bagValveMaskAvailable = true;
            attribute :>> suctionReady = true;
        }
        
        part powerSupply : PowerSupply {
            attribute :>> batteryCapacity = 500.0[W*h];
            attribute :>> batteryCharge = 475.0[W*h];
            attribute :>> acPowerConnected = false;
            attribute :>> outputVoltage = 12.0[V];
        }
        
        port monitoringInterface : MonitoringPort;
        port defibrillationInterface : DefibrillationPort;
        port oxygenInterface : OxygenDeliveryPort;
        
        perform action resuscitationProtocol : EmergencyResuscitation[*] ordered;
    }
    
    requirement def <'REQ-CC-001'> RapidResponseRequirement {
        doc /* The crash cart shall enable emergency response personnel to initiate 
                life-saving interventions within 60 seconds of arrival at patient location. */
        
        subject cart : CrashCart;
        
        require constraint responseTime {
            cart.operationalStatus == true
        }
    }
    
    requirement def <'REQ-CC-002'> DefibrillationCapabilityRequirement {
        doc /* The crash cart defibrillator shall deliver biphasic shocks up to 360 joules 
                for treatment of ventricular fibrillation and pulseless ventricular tachycardia. */
        
        subject defib : Defibrillator;
        
        require constraint energyCapacity {
            defib.maxEnergyCapacity >= 360.0[J]
        }
    }
    
    requirement def <'REQ-CC-003'> OxygenSupplyRequirement {
        doc /* The oxygen system shall provide continuous flow at adjustable rates 
                from 1 to 15 liters per minute for minimum duration of 30 minutes. */
        
        subject oxygen : OxygenSystem;
        
        require constraint flowCapability {
            oxygen.tankPressure >= 500.0[kPa]
        }
    }
    
    requirement def <'REQ-CC-004'> MedicationAvailabilityRequirement {
        doc /* The crash cart shall maintain immediate access to essential ACLS medications 
                including epinephrine, atropine, and amiodarone in appropriate quantities. */
        
        subject drawer : MedicationDrawer;
        
        require constraint medicationStock {
            drawer.inventoryComplete == true and not drawer.isLocked
        }
    }
    
    requirement def <'REQ-CC-005'> PowerReliabilityRequirement {
        doc /* The crash cart power supply shall maintain sufficient battery capacity 
                to operate all critical equipment for minimum 45 minutes without external power. */
        
        subject power : PowerSupply;
        
        require constraint batteryCapacity {
            power.batteryCharge >= 400.0[W*h]
        }
    }
    
    requirement <'SYS-CC-001'> crashCartSystemRequirement {
        doc /* The crash cart system shall provide comprehensive emergency cardiac life support 
                capabilities including defibrillation, cardiac monitoring, oxygen therapy, 
                medication administration, and airway management to enable rapid response 
                to cardiac and respiratory arrest situations. */
        
        subject crashCartSystem : CrashCart;
        
        require rapidResponse : RapidResponseRequirement;
        require defibrillationCapability : DefibrillationCapabilityRequirement;
        require oxygenSupply : OxygenSupplyRequirement;
        require medicationAvailability : MedicationAvailabilityRequirement;
        require powerReliability : PowerReliabilityRequirement;
    }
    
    part context emergencyDepartment {
        part erCrashCart : CrashCart {
            attribute :>> cartIdentifier = "CC-ER-001";
            attribute :>> locationAssigned = "Emergency Department Bay 3";
            attribute :>> lastInspectionDate = "2024-01-15";
            attribute :>> operationalStatus = true;
            attribute :>> totalWeight = 150.0[kg];
            
            perform action primaryResuscitation : EmergencyResuscitation;
        }
        
        part patientInterface {
            port vitalSignsMonitor : MonitoringPort;
            port shockPads : DefibrillationPort;
            port oxygenMask : OxygenDeliveryPort;
        }
        
        connect erCrashCart.monitoringInterface to patientInterface.vitalSignsMonitor;
        connect erCrashCart.defibrillationInterface to patientInterface.shockPads;
        connect erCrashCart.oxygenInterface to patientInterface.oxygenMask;
        
        flow erCrashCart.powerSupply.mainPower to erCrashCart.defibrillator.powerInput;
        flow erCrashCart.powerSupply.mainPower to erCrashCart.monitor.powerInput;
        
        satisfy crashCartSystemRequirement by erCrashCart;
    }
}
