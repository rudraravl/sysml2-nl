package 'Cryogenic Storage and Gas Delivery System' {
    private import ScalarValues::*;
    private import ScalarValues::Boolean;
    private import ISQ::*;
    
    attribute def TemperatureValue :> Real;
    attribute def PressureValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def FlowRateValue :> Real;
    
    item def CryogenicLiquid {
        attribute temperature : TemperatureValue;
        attribute volume : VolumeValue;
    }
    
    item def Gas {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
    }
    
    port def LiquidFlowPort {
        out item liquid : CryogenicLiquid;
    }
    
    port def GasFlowPort {
        out item gas : Gas;
    }
    
    part def InnerVessel {
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute internalPressure : PressureValue;
        attribute internalTemperature : TemperatureValue;
        port liquidOutPort : LiquidFlowPort;
        port reliefPort : GasFlowPort;
    }
    
    part def OuterShell {
        attribute ambientTemperature : TemperatureValue;
    }
    
    part def VacuumJacket {
        attribute vacuumLevel : PressureValue;
        attribute targetVacuumLevel : PressureValue;
    }
    
    part def VacuumPumpSystem {
        attribute measuredVacuum : PressureValue;
        attribute pumpCommand : Boolean;
        attribute threshold : PressureValue;
        
        state machine VacuumControl {
            state Monitoring;
            state Pumping;
            transition from Monitoring to Pumping when measuredVacuum > threshold;
            transition from Pumping to Monitoring when measuredVacuum <= threshold;
        }
    }
    
    part def EvaporatorCoil {
        port liquidInPort : ~LiquidFlowPort;
        port gasOutPort : GasFlowPort;
        
        perform action evaporate {
            in liquid : CryogenicLiquid;
            out gas : Gas;
        }
    }
    
    part def PressureRegulationValve {
        port gasInPort : ~GasFlowPort;
        port gasOutPort : GasFlowPort;
        attribute setPressure : PressureValue;
        attribute actualPressure : PressureValue;
        attribute tolerance : PressureValue;
        
        state machine PressureControl {
            state Closed;
            state Regulating;
            state FullOpen;
            transition from Closed to Regulating when actualPressure < setPressure;
            transition from Regulating to FullOpen when actualPressure < setPressure - tolerance;
            transition from FullOpen to Regulating when actualPressure >= setPressure - tolerance;
            transition from Regulating to Closed when actualPressure >= setPressure + tolerance;
        }
    }
    
    part def SafetyReliefValve {
        port gasInPort : ~GasFlowPort;
        port ventPort : GasFlowPort;
        attribute maxPressure : PressureValue;
        attribute currentPressure : PressureValue;
        
        state machine SafetyVenting {
            state Sealed;
            state Venting;
            transition from Sealed to Venting when currentPressure > maxPressure;
            transition from Venting to Sealed when currentPressure <= maxPressure * 0.95;
        }
    }
    
    part def LevelSensor {
        attribute measuredLevel : VolumeValue;
        attribute level : VolumeValue;
    }
    
    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        attribute pressure : PressureValue;
    }
    
    part def TemperatureSensor {
        attribute measuredTemperature : TemperatureValue;
        attribute temperature : TemperatureValue;
    }
    
    part def VacuumGauge {
        attribute measuredVacuum : PressureValue;
        attribute vacuum : PressureValue;
    }
    
    part def CryoSystem {
        part innerVessel : InnerVessel;
        part outerShell : OuterShell;
        part vacuumJacket : VacuumJacket;
        part vacuumPump : VacuumPumpSystem;
        part evaporator : EvaporatorCoil;
        part pressureRegulator : PressureRegulationValve;
        part safetyValve : SafetyReliefValve;
        part levelSensor : LevelSensor;
        part pressureSensor : PressureSensor;
        part tempSensor : TemperatureSensor;
        part vacuumGauge : VacuumGauge;
        
        flow of liquid : CryogenicLiquid
            from innerVessel.liquidOutPort.liquid to evaporator.liquidInPort.liquid;
        
        flow of gas : Gas
            from evaporator.gasOutPort.gas to pressureRegulator.gasInPort.gas;
        
        flow of gas : Gas
            from pressureRegulator.gasOutPort.gas to safetyValve.gasInPort.gas;
        
        bind vacuumPump.measuredVacuum = vacuumGauge.vacuum;
        bind levelSensor.measuredLevel = innerVessel.currentLevel;
        bind pressureSensor.measuredPressure = innerVessel.internalPressure;
        bind tempSensor.measuredTemperature = innerVessel.internalTemperature;
        bind vacuumGauge.measuredVacuum = vacuumJacket.vacuumLevel;
        bind safetyValve.currentPressure = innerVessel.internalPressure;
    }
    
    requirement def VacuumIntegrityReqDef {
        doc /* The vacuum jacket shall maintain a vacuum level below the maximum allowable pressure to minimize boil-off. */
        attribute vacuumPressure : PressureValue;
        attribute maxVacuumPressure : PressureValue;
        require constraint { vacuumPressure <= maxVacuumPressure }
    }
    
    requirement def PressureRegulationReqDef {
        doc /* The pressure regulation valve shall maintain output gas pressure within the specified tolerance. */
        attribute setPressure : PressureValue;
        attribute actualPressure : PressureValue;
        attribute tolerance : PressureValue;
        require constraint { 
            actualPressure <= setPressure + tolerance && 
            actualPressure >= setPressure - tolerance 
        }
    }
    
    requirement def SafetyReliefReqDef {
        doc /* The safety relief valve shall vent gas if internal pressure exceeds the maximum safe limit. */
        attribute internalPressure : PressureValue;
        attribute maxSafePressure : PressureValue;
        require constraint { internalPressure <= maxSafePressure }
    }
    
    requirement def BoilOffMinimizationReqDef {
        doc /* The system shall minimize cryogenic liquid boil-off through effective vacuum insulation. */
        attribute boilOffRate : FlowRateValue;
        attribute maxBoilOffRate : FlowRateValue;
        require constraint { boilOffRate <= maxBoilOffRate }
    }
    
    requirement def GasDeliveryReqDef {
        doc /* The system shall deliver regulated gas on demand at the specified flow rate. */
        attribute actualFlowRate : FlowRateValue;
        attribute minFlowRate : FlowRateValue;
        require constraint { actualFlowRate >= minFlowRate }
    }
    
    requirement def CryoSystemRequirements {
        requirement vacuumIntegrity : VacuumIntegrityReqDef {
            attribute maxVacuumPressure = 0.001;
        }
        requirement pressureRegulation : PressureRegulationReqDef {
            attribute tolerance = 0.5;
        }
        requirement safetyRelief : SafetyReliefReqDef {
            attribute maxSafePressure = 10.0;
        }
        requirement boilOffMinimization : BoilOffMinimizationReqDef {
            attribute maxBoilOffRate = 0.1;
        }
        requirement gasDelivery : GasDeliveryReqDef {
            attribute minFlowRate = 100.0;
        }
    }
}
