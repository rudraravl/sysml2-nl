package LaryngealTubeAirwaySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeviceID;
    attribute def PatientID;
    
    enum def TubeSizeEnum {
        size0;
        size1;
        size2;
        size2point5;
        size3;
        size4;
        size5;
    }
    
    enum def CuffStatusEnum {
        deflated;
        inflating;
        inflated;
        leaking;
    }
    
    enum def AirwayStatusEnum {
        obstructed;
        partiallyOpen;
        patent;
        sealed;
    }
    
    enum def VentilationModeEnum {
        manual;
        mechanical;
        spontaneous;
    }
    
    attribute def CuffPressure :> ISQ::PressureValue {
        doc /* Pressure within laryngeal tube cuffs measured in cmH2O */
    }
    
    attribute def AirVolume :> ISQ::VolumeValue {
        doc /* Volume of air for cuff inflation or tidal volume */
    }
    
    attribute def RespiratoryRate :> ISQ::FrequencyValue {
        doc /* Breaths per minute */
    }
    
    port def AirwayPort {
        out item airflow : ISQ::VolumeFlowRateValue;
        in item resistance : ISQ::PressureValue;
    }
    
    port def CuffInflationPort {
        in item inflationVolume : AirVolume;
        out item currentPressure : CuffPressure;
    }
    
    port def VentilationPort {
        in item tidalVolume : AirVolume;
        in item respiratoryRate : RespiratoryRate;
        out item deliveredVolume : AirVolume;
    }
    
    part def ProximalCuff {
        doc /* Oropharyngeal cuff that seals the upper airway */
        attribute cuffPressure : CuffPressure;
        attribute targetVolume : AirVolume;
        attribute status : CuffStatusEnum;
        port inflationPort : CuffInflationPort;
    }
    
    part def DistalCuff {
        doc /* Esophageal cuff that prevents gastric insufflation */
        attribute cuffPressure : CuffPressure;
        attribute targetVolume : AirVolume;
        attribute status : CuffStatusEnum;
        port inflationPort : CuffInflationPort;
    }
    
    part def VentilationLumen {
        doc /* Central channel for gas delivery to trachea */
        attribute innerDiameter : ISQ::LengthValue;
        attribute length : ISQ::LengthValue;
        attribute resistance : ISQ::PressureValue;
        port proximalPort : VentilationPort;
        port distalPort : AirwayPort;
    }
    
    part def InflationLine {
        doc /* Dual-lumen line for simultaneous cuff inflation */
        attribute innerDiameter : ISQ::LengthValue;
        port externalPort : CuffInflationPort;
        port proximalCuffPort : CuffInflationPort;
        port distalCuffPort : CuffInflationPort;
    }
    
    part def PilotBalloon {
        doc /* Visual and tactile indicator of cuff inflation */
        attribute pressure : CuffPressure;
        attribute firmness : Real;
        port monitorPort : CuffInflationPort;
    }
    
    part def LaryngealTubeDevice {
        doc /* Supraglottic airway device for emergency ventilation */
        attribute deviceID : DeviceID;
        attribute tubeSize : TubeSizeEnum;
        attribute insertionDepth : ISQ::LengthValue;
        attribute material : String;
        
        part proximalCuff : ProximalCuff {
            attribute :>> targetVolume = 60.0;
        }
        
        part distalCuff : DistalCuff {
            attribute :>> targetVolume = 40.0;
        }
        
        part ventilationLumen : VentilationLumen {
            attribute :>> innerDiameter = 7.5;
            attribute :>> length = 280.0;
        }
        
        part inflationLine : InflationLine {
            attribute :>> innerDiameter = 2.0;
        }
        
        part pilotBalloon : PilotBalloon;
        
        connection proximalCuffConnection 
            connect inflationLine.proximalCuffPort to proximalCuff.inflationPort;
        
        connection distalCuffConnection 
            connect inflationLine.distalCuffPort to distalCuff.inflationPort;
        
        connection pilotConnection 
            connect inflationLine.externalPort to pilotBalloon.monitorPort;
    }
    
    part def Patient {
        doc /* Patient requiring emergency airway management */
        attribute patientID : PatientID;
        attribute airwayStatus : AirwayStatusEnum;
        attribute oxygenSaturation : Real;
        port airwayPort : AirwayPort;
    }
    
    part def InflationSyringe {
        doc /* Syringe for manual cuff inflation */
        attribute capacity : AirVolume;
        attribute currentVolume : AirVolume;
        port deliveryPort : CuffInflationPort;
    }
    
    part def VentilationSource {
        doc /* Manual or mechanical ventilation device */
        attribute mode : VentilationModeEnum;
        attribute tidalVolume : AirVolume;
        attribute respiratoryRate : RespiratoryRate;
        attribute peakPressure : ISQ::PressureValue;
        port ventilationPort : VentilationPort;
    }
    
    part def MonitoringSystem {
        doc /* Monitors airway pressure and ventilation parameters */
        attribute airwayPressure : ISQ::PressureValue;
        attribute tidalVolumeDelivered : AirVolume;
        attribute leakDetected : Boolean;
    }
    
    action def InsertDevice {
        doc /* Insert laryngeal tube into patient airway */
        in patient : Patient;
        in device : LaryngealTubeDevice;
        in targetDepth : ISQ::LengthValue;
        out insertionSuccessful : Boolean;
        out finalDepth : ISQ::LengthValue;
    }
    
    action def InflateCuffs {
        doc /* Inflate both cuffs to establish airway seal */
        in proximalCuff : ProximalCuff;
        in distalCuff : DistalCuff;
        in targetPressure : CuffPressure;
        out proximalStatus : CuffStatusEnum;
        out distalStatus : CuffStatusEnum;
        out sealAchieved : Boolean;
    }
    
    action def VerifyPlacement {
        doc /* Confirm proper device placement and seal */
        in device : LaryngealTubeDevice;
        in patient : Patient;
        out placementCorrect : Boolean;
        out sealIntegrity : Real;
    }
    
    action def DeliverVentilation {
        doc /* Deliver positive pressure breath to patient */
        in tidalVolume : AirVolume;
        in pressure : ISQ::PressureValue;
        out volumeDelivered : AirVolume;
        out peakPressure : ISQ::PressureValue;
    }
    
    action def MonitorAirway {
        doc /* Continuously monitor airway patency and seal */
        in device : LaryngealTubeDevice;
        in patient : Patient;
        out airwayPatent : Boolean;
        out cuffPressureAdequate : Boolean;
        out leakPresent : Boolean;
    }
    
    action def AdjustCuffPressure {
        doc /* Adjust cuff pressure to maintain seal */
        in currentPressure : CuffPressure;
        in targetPressure : CuffPressure;
        out adjustedPressure : CuffPressure;
    }
    
    action def DeflateCuffs {
        doc /* Deflate cuffs prior to device removal */
        in proximalCuff : ProximalCuff;
        in distalCuff : DistalCuff;
        out proximalStatus : CuffStatusEnum;
        out distalStatus : CuffStatusEnum;
    }
    
    action def RemoveDevice {
        doc /* Remove laryngeal tube from patient */
        in device : LaryngealTubeDevice;
        in patient : Patient;
        out removalComplete : Boolean;
    }
    
    action def EstablishEmergencyAirway {
        doc /* Complete sequence to establish emergency airway */
        in patient : Patient;
        in device : LaryngealTubeDevice;
        in syringe : InflationSyringe;
        out airwayEstablished : Boolean;
        
        first start;
        
        then merge retryInsertion;
        
        then action insert : InsertDevice {
            in patient = EstablishEmergencyAirway::patient;
            in device = EstablishEmergencyAirway::device;
            in targetDepth = 23.0;
            out insertionSuccessful;
            out finalDepth;
        }
        
        then decide;
            if insert.insertionSuccessful then proceedToInflation;
            if !insert.insertionSuccessful then repositionDevice;
        
        action repositionDevice;
        then retryInsertion;
        
        action proceedToInflation;
        
        then action inflate : InflateCuffs {
            in proximalCuff = device.proximalCuff;
            in distalCuff = device.distalCuff;
            in targetPressure = 60.0;
            out proximalStatus;
            out distalStatus;
            out sealAchieved;
        }
        
        then action verify : VerifyPlacement {
            in device = EstablishEmergencyAirway::device;
            in patient = EstablishEmergencyAirway::patient;
            out placementCorrect;
            out sealIntegrity;
        }
        
        then decide;
            if verify.placementCorrect then confirmAirway;
            if !verify.placementCorrect then adjustDevice;
        
        action adjustDevice;
        then retryInsertion;
        
        action confirmAirway;
        then assign airwayEstablished := true;
        
        then done;
    }
    
    action def MaintainVentilation {
        doc /* Maintain continuous ventilation through established airway */
        in device : LaryngealTubeDevice;
        in patient : Patient;
        in ventilator : VentilationSource;
        
        first start;
        then merge ventilationCycle;
        
        then action monitor : MonitorAirway {
            in device = MaintainVentilation::device;
            in patient = MaintainVentilation::patient;
            out airwayPatent;
            out cuffPressureAdequate;
            out leakPresent;
        }
        
        then decide;
            if monitor.airwayPatent then deliverBreath;
            if !monitor.cuffPressureAdequate then adjustPressure;
            if !monitor.airwayPatent then repositionRequired;
        
        action deliverBreath : DeliverVentilation {
            in tidalVolume = ventilator.tidalVolume;
            in pressure = ventilator.peakPressure;
            out volumeDelivered;
            out peakPressure;
        }
        then ventilationCycle;
        
        action adjustPressure : AdjustCuffPressure {
            in currentPressure = device.proximalCuff.cuffPressure;
            in targetPressure = 60.0;
            out adjustedPressure;
        }
        then ventilationCycle;
        
        action repositionRequired;
        then done;
    }
    
    action def TerminateAirwayManagement {
        doc /* Safely remove laryngeal tube when no longer needed */
        in device : LaryngealTubeDevice;
        in patient : Patient;
        out terminationSuccessful : Boolean;
        
        first start;
        
        then action deflate : DeflateCuffs {
            in proximalCuff = device.proximalCuff;
            in distalCuff = device.distalCuff;
            out proximalStatus;
            out distalStatus;
        }
        
        then action remove : RemoveDevice {
            in device = TerminateAirwayManagement::device;
            in patient = TerminateAirwayManagement::patient;
            out removalComplete;
        }
        
        then assign terminationSuccessful := remove.removalComplete;
        then done;
    }
    
    part laryngealTubeSystem {
        doc /* 
            Emergency airway management system using laryngeal tube.
            Primary function: Establish and maintain a patent supraglottic airway
            for emergency ventilation in patients requiring immediate airway control.
            The dual-cuff design creates an effective seal to enable positive pressure
            ventilation while preventing aspiration and gastric insufflation.
        */
        
        part device : LaryngealTubeDevice {
            attribute :>> deviceID = "LT-001";
            attribute :>> tubeSize = TubeSizeEnum::size4;
            attribute :>> material = "Medical-grade silicone";
        }
        
        part targetPatient : Patient {
            attribute :>> patientID = "PT-001";
            attribute :>> airwayStatus = AirwayStatusEnum::obstructed;
            attribute :>> oxygenSaturation = 85.0;
        }
        
        part inflationDevice : InflationSyringe {
            attribute :>> capacity = 100.0;
            attribute :>> currentVolume = 100.0;
        }
        
        part ventilator : VentilationSource {
            attribute :>> mode = VentilationModeEnum::manual;
            attribute :>> tidalVolume = 500.0;
            attribute :>> respiratoryRate = 12.0;
            attribute :>> peakPressure = 20.0;
        }
        
        part monitor : MonitoringSystem {
            attribute :>> leakDetected = false;
        }
        
        connection deviceToPatient 
            connect device.ventilationLumen.distalPort to targetPatient.airwayPort;
        
        connection inflationConnection 
            connect inflationDevice.deliveryPort to device.inflationLine.externalPort;
        
        connection ventilatorConnection 
            connect ventilator.ventilationPort to device.ventilationLumen.proximalPort;
        
        perform action completeAirwayManagement {
            doc /* Complete airway management workflow from insertion to removal */
            
            first start;
            
            then action establish : EstablishEmergencyAirway {
                in patient = targetPatient;
                in device = device;
                in syringe = inflationDevice;
                out airwayEstablished;
            }
            
            then decide;
                if establish.airwayEstablished then beginVentilation;
                if !establish.airwayEstablished then abortProcedure;
            
            action beginVentilation;
            
            then action maintain : MaintainVentilation {
                in device = device;
                in patient = targetPatient;
                in ventilator = ventilator;
            }
            
            accept terminationSignal;
            
            then action terminate : TerminateAirwayManagement {
                in device = device;
                in patient = targetPatient;
                out terminationSuccessful;
            }
            
            then done;
            
            action abortProcedure;
            then done;
        }
    }
    
    requirement def AirwayPatencyRequirement {
        doc /* System shall establish and maintain patent airway */
        
        require constraint {
            laryngealTubeSystem.targetPatient.airwayStatus == AirwayStatusEnum::sealed ||
            laryngealTubeSystem.targetPatient.airwayStatus == AirwayStatusEnum::patent
        }
    }
    
    requirement def CuffPressureRequirement {
        doc /* Cuff pressure shall remain within safe therapeutic range */
        
        require constraint {
            laryngealTubeSystem.device.proximalCuff.cuffPressure >= 40.0 &&
            laryngealTubeSystem.device.proximalCuff.cuffPressure <= 70.0 &&
            laryngealTubeSystem.device.distalCuff.cuffPressure >= 40.0 &&
            laryngealTubeSystem.device.distalCuff.cuffPressure <= 70.0
        }
    }
    
    requirement def VentilationEffectivenessRequirement {
        doc /* System shall deliver adequate tidal volume with minimal leak */
        
        require constraint {
            laryngealTubeSystem.ventilator.tidalVolume >= 400.0 &&
            laryngealTubeSystem.ventilator.tidalVolume <= 600.0 &&
            !laryngealTubeSystem.monitor.leakDetected
        }
    }
    
    requirement def OxygenationRequirement {
        doc /* System shall improve patient oxygenation */
        
        require constraint {
            laryngealTubeSystem.targetPatient.oxygenSaturation >= 92.0
        }
    }
    
    requirement <'LTS-REQ-001'> emergencyAirwayRequirements {
        doc /* 
            The laryngeal tube system shall provide rapid, effective emergency
            airway management by establishing a sealed supraglottic airway that
            enables positive pressure ventilation while preventing aspiration
            and gastric insufflation in patients requiring immediate airway control.
        */
        
        require airwayPatencyRequirement;
        require cuffPressureRequirement;
        require ventilationEffectivenessRequirement;
        require oxygenationRequirement;
    }
}
