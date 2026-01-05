package BakriBalloonTamponadeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def VolumeValue :> VolumeValue;
    attribute def PressureValue :> PressureValue;
    attribute def FlowRateValue :> VolumeFlowRateValue;
    attribute def TimeValue :> DurationValue;
    
    item def SalineSolution {
        attribute temperature : TemperatureValue;
        attribute sterility : Boolean;
    }
    
    item def Blood {
        attribute volume : VolumeValue;
        attribute flowRate : FlowRateValue;
    }
    
    port def SalineInflowPort {
        in item saline : SalineSolution;
    }
    
    port def BloodDrainagePort {
        out item blood : Blood;
    }
    
    port def PressureMonitorPort {
        out value p : PressureValue;
    }
    
    port def VolumeMonitorPort {
        out value v : VolumeValue;
    }
    
    part def SiliconeBallon {
        attribute currentVolume : VolumeValue;
        attribute maxVolume : VolumeValue = 500.0;
        attribute internalPressure : PressureValue;
        attribute isInflated : Boolean = false;
        
        port inflationPort : SalineInflowPort;
        port drainagePort : BloodDrainagePort;
        port pressurePort : PressureMonitorPort {
            out value p = internalPressure;
        }
        port volumePort : VolumeMonitorPort {
            out value v = currentVolume;
        }
    }
    
    part def CatheterShaft {
        attribute length : LengthValue = 540.0;
        attribute outerDiameter : LengthValue = 24.0;
        attribute drainageLumenDiameter : LengthValue = 14.0;
        
        port proximalInflation : SalineInflowPort;
        port distalInflation : SalineInflowPort;
        port proximalDrainage : BloodDrainagePort;
        port distalDrainage : BloodDrainagePort;
    }
    
    part def InflationSyringe {
        attribute capacity : VolumeValue = 60.0;
        attribute deliveredVolume : VolumeValue;
        
        port salineOutput : SalineInflowPort;
        
        action def DeliverSaline {
            in targetVolume : VolumeValue;
            out actualVolume : VolumeValue;
        }
    }
    
    part def DrainageCollectionBag {
        attribute totalCollected : VolumeValue;
        attribute maxCapacity : VolumeValue = 2000.0;
        
        port bloodInlet : BloodDrainagePort;
    }
    
    part def PressureGauge {
        attribute reading : PressureValue;
        attribute maxReading : PressureValue = 40.0;
        
        port monitorPort : PressureMonitorPort;
    }
    
    action def InsertCatheter {
        out inserted : Boolean;
    }
    
    action def InflateBalloon {
        in targetVolume : VolumeValue;
        in inflationRate : FlowRateValue;
        out currentVolume : VolumeValue;
        out pressure : PressureValue;
    }
    
    action def MaintainTamponade {
        in requiredPressure : PressureValue;
        out actualPressure : PressureValue;
        out volumeStable : Boolean;
    }
    
    action def MonitorBloodLoss {
        out drainageVolume : VolumeValue;
        out drainageRate : FlowRateValue;
        out hemorrhageControlled : Boolean;
    }
    
    action def DeflateBalloon {
        out deflated : Boolean;
    }
    
    action def RemoveDevice {
        out removed : Boolean;
    }
    
    action def ControlPostpartumHemorrhage {
        in targetTamponadeVolume : VolumeValue;
        in maxTreatmentDuration : TimeValue;
        out hemorrhageControlled : Boolean;
        out totalBloodLoss : VolumeValue;
        
        first start;
        
        then action insert : InsertCatheter {
            out inserted : Boolean;
        }
        
        then action inflate : InflateBalloon {
            in targetVolume = targetTamponadeVolume;
            in inflationRate = 50.0;
            out currentVolume : VolumeValue;
            out pressure : PressureValue;
        }
        
        then action maintain : MaintainTamponade {
            in requiredPressure = inflate.pressure;
            out actualPressure : PressureValue;
            out volumeStable : Boolean;
        }
        
        then merge continuousMonitoring;
        
        then action monitor : MonitorBloodLoss {
            out drainageVolume : VolumeValue;
            out drainageRate : FlowRateValue;
            out hemorrhageControlled : Boolean;
        }
        
        then decide;
            if monitor.hemorrhageControlled then proceedToDeflate;
            if !monitor.hemorrhageControlled and monitor.drainageRate > 50.0 then adjustTamponade;
        
        action adjustTamponade : InflateBalloon {
            in targetVolume = targetTamponadeVolume;
            in inflationRate = 30.0;
        }
        then continuousMonitoring;
        
        action proceedToDeflate;
        
        then action deflate : DeflateBalloon {
            out deflated : Boolean;
        }
        
        then action remove : RemoveDevice {
            out removed : Boolean;
        }
        
        then done;
    }
    
    part def BakriBalloonSystem {
        attribute maxInflationVolume : VolumeValue = 500.0;
        attribute minInflationVolume : VolumeValue = 300.0;
        attribute targetPressure : PressureValue = 10.0;
        attribute maxPressure : PressureValue = 35.0;
        attribute treatmentDuration : TimeValue = 24.0;
        
        part balloon : SiliconeBallon {
            attribute :>> maxVolume = 500.0;
            attribute :>> currentVolume = 0.0;
            attribute :>> internalPressure = 0.0;
        }
        
        part catheter : CatheterShaft {
            attribute :>> length = 540.0;
        }
        
        part syringe : InflationSyringe {
            attribute :>> capacity = 60.0;
        }
        
        part collectionBag : DrainageCollectionBag {
            attribute :>> totalCollected = 0.0;
        }
        
        part pressureMonitor : PressureGauge {
            attribute :>> reading = 0.0;
        }
        
        connect syringe.salineOutput to catheter.proximalInflation;
        connect catheter.distalInflation to balloon.inflationPort;
        connect balloon.drainagePort to catheter.distalDrainage;
        connect catheter.proximalDrainage to collectionBag.bloodInlet;
        connect balloon.pressurePort to pressureMonitor.monitorPort;
        
        item flow of SalineSolution from syringe.salineOutput to balloon.inflationPort;
        item flow of Blood from balloon.drainagePort to collectionBag.bloodInlet;
        
        assert constraint volumeLimit {
            balloon.currentVolume <= balloon.maxVolume
        }
        
        assert constraint pressureSafety {
            balloon.internalPressure <= maxPressure
        }
        
        assert constraint minVolumeThreshold {
            balloon.currentVolume >= minInflationVolume or balloon.currentVolume == 0.0
        }
        
        perform action tamponadeOperation : ControlPostpartumHemorrhage {
            in targetTamponadeVolume = maxInflationVolume;
            in maxTreatmentDuration = treatmentDuration;
            out hemorrhageControlled : Boolean;
            out totalBloodLoss = collectionBag.totalCollected;
        }
    }
    
    requirement def FunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    
    requirement <'REQ-100'> primaryFunction : FunctionalRequirement {
        doc /* The Bakri balloon system shall provide intrauterine tamponade 
             * to control postpartum hemorrhage by applying mechanical pressure 
             * to the uterine wall through controlled balloon inflation.
             */
        subject system : BakriBalloonSystem;
    }
    
    requirement <'REQ-101'> volumeCapacity : PerformanceRequirement {
        doc /* The balloon shall accommodate inflation volumes between 
             * 300 mL and 500 mL to provide effective tamponade coverage.
             */
        subject balloon : BakriBalloonSystem::balloon;
        assert constraint {
            balloon.currentVolume >= 300.0 and balloon.currentVolume <= 500.0
        }
    }
    
    requirement <'REQ-102'> pressureControl : SafetyRequirement {
        doc /* The system shall maintain balloon pressure below 35 kPa 
             * to prevent uterine tissue damage while ensuring effective tamponade.
             */
        subject system : BakriBalloonSystem;
        assert constraint {
            system.balloon.internalPressure <= system.maxPressure
        }
    }
    
    requirement <'REQ-103'> drainageMonitoring : FunctionalRequirement {
        doc /* The system shall enable continuous drainage and monitoring 
             * of blood loss to assess treatment effectiveness.
             */
        subject system : BakriBalloonSystem;
        require system.collectionBag.bloodInlet;
    }
    
    requirement <'REQ-104'> rapidDeployment : PerformanceRequirement {
        doc /* The system shall achieve full balloon inflation within 
             * 5 minutes of insertion to rapidly control hemorrhage.
             */
        subject system : BakriBalloonSystem;
    }
    
    part bakriSystem : BakriBalloonSystem;
    
    satisfy primaryFunction by bakriSystem.tamponadeOperation;
    satisfy volumeCapacity by bakriSystem.balloon;
    satisfy pressureControl by bakriSystem;
    satisfy drainageMonitoring by bakriSystem;
    satisfy rapidDeployment by bakriSystem;
}
