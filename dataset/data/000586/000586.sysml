package 'Dodrill_GMR_Heart_Lung_Machine' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    doc /* 
        This model describes the Dodrill-GMR mechanical heart-lung machine, 
        a pioneering extracorporeal circulation system developed in the early 1950s. 
        Its primary function is to temporarily replace the pumping action of the heart 
        and the gas exchange function of the lungs during cardiac surgery, allowing 
        surgeons to operate on a motionless, bloodless heart while maintaining 
        circulation and oxygenation throughout the patient's body.
    */

    attribute def BloodOxygenSaturation :> Real;
    attribute def BloodFlowRate :> VolumetricFlowRateValue;
    attribute def BloodPressure :> PressureValue;
    attribute def BloodTemperature :> ThermodynamicTemperatureValue;
    attribute def CO2Concentration :> Real;
    attribute def PumpRotationSpeed :> Real;
    
    attribute def BypassStartCommand;
    attribute def BypassStopCommand;
    attribute def EmergencyShutdown;

    port def BloodFlowPort {
        attribute venousBlood : BloodFlowRate;
        attribute arterialBlood : BloodFlowRate;
    }

    port def GasExchangePort {
        attribute oxygenSupply : VolumetricFlowRateValue;
        attribute carbonDioxideExhaust : VolumetricFlowRateValue;
    }

    part def VenousCannula {
        doc /* Cannula inserted into patient's venous system to drain deoxygenated blood */
        port patientVenousConnection;
        port machineInletConnection;
    }

    part def ArterialCannula {
        doc /* Cannula inserted into patient's arterial system to return oxygenated blood */
        port machineOutletConnection;
        port patientArterialConnection;
    }

    part def VenousReservoir {
        doc /* Collects venous blood and provides volume buffer */
        attribute capacity : VolumeValue;
        attribute currentLevel : LengthValue;
        port bloodInlet;
        port bloodOutlet;
    }

    part def RollerPump {
        doc /* Mechanical pump using rotating rollers to propel blood through tubing */
        attribute rotationSpeed : PumpRotationSpeed;
        attribute outputFlow : BloodFlowRate;
        attribute outputPressure : BloodPressure;
        port bloodInlet;
        port bloodOutlet;
    }

    part def BubbleOxygenator {
        doc /* Oxygenates blood by bubbling oxygen through it and removes CO2 */
        attribute oxygenFlowRate : VolumetricFlowRateValue;
        attribute bloodOxygenation : BloodOxygenSaturation;
        attribute co2Removal : CO2Concentration;
        port bloodInlet;
        port bloodOutlet;
        port oxygenInlet;
        port exhaustOutlet;
    }

    part def HeatExchangerUnit {
        doc /* Maintains blood temperature during extracorporeal circulation */
        attribute targetTemperature : BloodTemperature;
        attribute actualTemperature : BloodTemperature;
        port bloodInlet;
        port bloodOutlet;
        port coolantInlet;
        port coolantOutlet;
    }

    part def BloodFilter {
        doc /* Removes particulates, microemboli, and debris from blood */
        port bloodInlet;
        port bloodOutlet;
    }

    part def MonitoringConsole {
        doc /* Monitors critical parameters during bypass operation */
        attribute measuredFlowRate : BloodFlowRate;
        attribute measuredPressure : BloodPressure;
        attribute measuredTemperature : BloodTemperature;
        attribute measuredOxygenation : BloodOxygenSaturation;
        attribute systemStatus : Real;
    }

    action def DrainVenousBlood {
        doc /* Drains deoxygenated blood from patient's venous system */
        in venousPressure : BloodPressure;
        out deoxygenatedBloodFlow : BloodFlowRate;
    }

    action def CollectBlood {
        doc /* Collects blood in reservoir and maintains volume */
        in bloodFlow : BloodFlowRate;
        out reservoirOutput : BloodFlowRate;
        out reservoirLevel : LengthValue;
    }

    action def PumpBlood {
        doc /* Pumps blood through the circuit at controlled flow rate */
        in bloodInput : BloodFlowRate;
        in targetFlow : BloodFlowRate;
        out pressurizedBlood : BloodFlowRate;
        out pumpPressure : BloodPressure;
    }

    action def OxygenateBlood {
        doc /* Adds oxygen to blood and removes carbon dioxide */
        in deoxygenatedBlood : BloodFlowRate;
        in oxygenFlow : VolumetricFlowRateValue;
        out oxygenatedBlood : BloodFlowRate;
        out oxygenSaturation : BloodOxygenSaturation;
        out removedCO2 : CO2Concentration;
    }

    action def RegulateTemperature {
        doc /* Controls blood temperature to physiological range */
        in bloodInput : BloodFlowRate;
        in temperatureSetpoint : BloodTemperature;
        out temperatureControlledBlood : BloodFlowRate;
        out actualTemp : BloodTemperature;
    }

    action def FilterBlood {
        doc /* Filters blood to remove debris and emboli */
        in unfilteredBlood : BloodFlowRate;
        out filteredBlood : BloodFlowRate;
    }

    action def ReturnArterialBlood {
        doc /* Returns oxygenated blood to patient's arterial circulation */
        in oxygenatedBlood : BloodFlowRate;
        in arterialPressure : BloodPressure;
        out deliveredBlood : BloodFlowRate;
    }

    action def MonitorSystemParameters {
        doc /* Continuously monitors all critical system parameters */
        in flowRate : BloodFlowRate;
        in pressure : BloodPressure;
        in temperature : BloodTemperature;
        in oxygenation : BloodOxygenSaturation;
        out status : Real;
    }

    action def PerformCardiopulmonaryBypass {
        doc /* 
            Main operational cycle of the heart-lung machine performing 
            complete cardiopulmonary bypass 
        */
        in targetFlowRate : BloodFlowRate;
        in targetTemperature : BloodTemperature;
        in oxygenSupplyRate : VolumetricFlowRateValue;
        out patientPerfusion : BloodFlowRate;
        out systemOxygenation : BloodOxygenSaturation;

        first start;
        then merge continueBypass;
        
        action drainVenous : DrainVenousBlood {
            in venousPressure : BloodPressure;
            out deoxygenatedBloodFlow : BloodFlowRate;
        }

        flow drainVenous.deoxygenatedBloodFlow to collectBlood.bloodFlow;

        then action collectBlood : CollectBlood {
            in bloodFlow : BloodFlowRate;
            out reservoirOutput : BloodFlowRate;
            out reservoirLevel : LengthValue;
        }

        flow collectBlood.reservoirOutput to pumpBlood.bloodInput;

        then action pumpBlood : PumpBlood {
            in bloodInput : BloodFlowRate;
            in targetFlow = targetFlowRate;
            out pressurizedBlood : BloodFlowRate;
            out pumpPressure : BloodPressure;
        }

        flow pumpBlood.pressurizedBlood to oxygenateBlood.deoxygenatedBlood;

        then action oxygenateBlood : OxygenateBlood {
            in deoxygenatedBlood : BloodFlowRate;
            in oxygenFlow = oxygenSupplyRate;
            out oxygenatedBlood : BloodFlowRate;
            out oxygenSaturation : BloodOxygenSaturation;
            out removedCO2 : CO2Concentration;
        }

        flow oxygenateBlood.oxygenatedBlood to regulateTemp.bloodInput;

        then action regulateTemp : RegulateTemperature {
            in bloodInput : BloodFlowRate;
            in temperatureSetpoint = targetTemperature;
            out temperatureControlledBlood : BloodFlowRate;
            out actualTemp : BloodTemperature;
        }

        flow regulateTemp.temperatureControlledBlood to filterBlood.unfilteredBlood;

        then action filterBlood : FilterBlood {
            in unfilteredBlood : BloodFlowRate;
            out filteredBlood : BloodFlowRate;
        }

        flow filterBlood.filteredBlood to returnArterial.oxygenatedBlood;

        then action returnArterial : ReturnArterialBlood {
            in oxygenatedBlood : BloodFlowRate;
            in arterialPressure : BloodPressure;
            out deliveredBlood : BloodFlowRate;
        }

        then action monitorParams : MonitorSystemParameters {
            in flowRate = pumpBlood.pressurizedBlood;
            in pressure = pumpBlood.pumpPressure;
            in temperature = regulateTemp.actualTemp;
            in oxygenation = oxygenateBlood.oxygenSaturation;
            out status : Real;
        }

        then decide;
            if monitorParams.status >= 0.0 then continueBypass;
            if monitorParams.status < 0.0 then emergencyStop;

        action emergencyStop;
        then done;
    }

    part dodrillGMRSystem : 'Dodrill-GMR Heart-Lung Machine' {
        doc /* 
            Complete Dodrill-GMR mechanical heart-lung machine system 
            providing total cardiopulmonary bypass support during cardiac surgery 
        */

        perform action bypassOperation[*] ordered references PerformCardiopulmonaryBypass;

        part venousCannula : VenousCannula {
            doc /* Drains deoxygenated blood from patient */
        }

        part reservoir : VenousReservoir {
            doc /* Blood collection reservoir */
            perform bypassOperation.collectBlood;
        }

        part pump : RollerPump {
            doc /* Main blood pump */
            perform bypassOperation.pumpBlood;
        }

        part oxygenator : BubbleOxygenator {
            doc /* Blood oxygenation unit */
            perform bypassOperation.oxygenateBlood;
        }

        part heatExchanger : HeatExchangerUnit {
            doc /* Temperature control unit */
            perform bypassOperation.regulateTemp;
        }

        part filter : BloodFilter {
            doc /* Blood filtration unit */
            perform bypassOperation.filterBlood;
        }

        part arterialCannula : ArterialCannula {
            doc /* Returns oxygenated blood to patient */
            perform bypassOperation.returnArterial;
        }

        part monitor : MonitoringConsole {
            doc /* System monitoring and control */
            perform bypassOperation.monitorParams;
        }

        connect venousCannula.machineInletConnection to reservoir.bloodInlet;
        connect reservoir.bloodOutlet to pump.bloodInlet;
        connect pump.bloodOutlet to oxygenator.bloodInlet;
        connect oxygenator.bloodOutlet to heatExchanger.bloodInlet;
        connect heatExchanger.bloodOutlet to filter.bloodInlet;
        connect filter.bloodOutlet to arterialCannula.machineOutletConnection;
    }

    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    requirement def ReliabilityRequirement;

    requirement <'DGMR-REQ-001'> maintainAdequatePerfusion : PerformanceRequirement {
        doc /* 
            The system shall maintain adequate tissue perfusion by delivering 
            oxygenated blood at a flow rate between 2.4 and 5.0 liters per minute 
            for an average adult patient during cardiopulmonary bypass.
        */
        subject dodrillGMRSystem;
    }

    requirement <'DGMR-REQ-002'> achieveAdequateOxygenation : PerformanceRequirement {
        doc /* 
            The system shall achieve and maintain arterial blood oxygen saturation 
            at or above 95% throughout the bypass procedure.
        */
        subject dodrillGMRSystem;
    }

    requirement <'DGMR-REQ-003'> maintainPhysiologicTemperature : SafetyRequirement {
        doc /* 
            The system shall maintain blood temperature between 32°C and 37°C 
            to prevent thermal injury while allowing controlled hypothermia 
            when clinically indicated.
        */
        subject dodrillGMRSystem;
    }

    requirement <'DGMR-REQ-004'> preventAirEmbolism : SafetyRequirement {
        doc /* 
            The system shall prevent air from entering the arterial circulation 
            by maintaining adequate reservoir level and incorporating air detection 
            and removal mechanisms.
        */
        subject dodrillGMRSystem;
    }

    requirement <'DGMR-REQ-005'> maintainArterialPressure : PerformanceRequirement {
        doc /* 
            The system shall maintain mean arterial pressure between 50 and 80 mmHg 
            during bypass to ensure adequate organ perfusion.
        */
        subject dodrillGMRSystem;
    }

    requirement <'DGMR-REQ-006'> ensureContinuousOperation : ReliabilityRequirement {
        doc /* 
            The system shall operate continuously without mechanical failure 
            for the duration of cardiac surgery procedures, typically 2 to 6 hours.
        */
        subject dodrillGMRSystem;
    }

    requirement missionRequirement {
        doc /* 
            Primary mission: Enable cardiac surgery by temporarily replacing 
            heart and lung function through extracorporeal circulation and oxygenation.
        */
        require maintainAdequatePerfusion;
        require achieveAdequateOxygenation;
        require maintainPhysiologicTemperature;
        require preventAirEmbolism;
        require maintainArterialPressure;
        require ensureContinuousOperation;
    }
}
