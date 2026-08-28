package 'Traction Control System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def WheelSpeedValue :> Real { unit ISQ::AngularVelocity; }
    attribute def VehicleSpeedValue :> Real { unit ISQ::Velocity; }
    attribute def SlipRatioValue :> Real;
    attribute def TorqueCommandValue :> Real { unit ISQ::Torque; }
    attribute def TemperatureValue :> Real { unit ISQ::Temperature; }
    
    part def VelocitySensor {
        port measuredWheelSpeedPort {
            in measuredWheelSpeed : WheelSpeedValue;
        }
        port wheelSpeedPort {
            out wheelSpeed : WheelSpeedValue;
        }
        port vehicleSpeedPort {
            out vehicleSpeed : VehicleSpeedValue;
        }
        port sensorTempPort {
            out sensorTemp : TemperatureValue;
        }
        action senseSpeeds {
            in measuredWheelSpeed : WheelSpeedValue;
            out wheelSpeed : WheelSpeedValue;
            out vehicleSpeed : VehicleSpeedValue;
        }
    }
    
    part def SlipEstimator {
        port wheelSpeedPort {
            in wheelSpeed : WheelSpeedValue;
        }
        port vehicleSpeedPort {
            in vehicleSpeed : VehicleSpeedValue;
        }
        port slipRatioPort {
            out slipRatio : SlipRatioValue;
        }
        action estimateSlip {
            in wheelSpeed : WheelSpeedValue;
            in vehicleSpeed : VehicleSpeedValue;
            out slipRatio : SlipRatioValue;
        }
    }
    
    part def TractionController {
        attribute targetSlipRatio : SlipRatioValue = 0.05;
        port slipRatioPort {
            in slipRatio : SlipRatioValue;
        }
        port torqueCommandPort {
            out torqueCommand : TorqueCommandValue;
        }
        port wheelTempPort {
            in wheelTemp : TemperatureValue;
        }
        port powertrainTempPort {
            in powertrainTemp : TemperatureValue;
        }
        port actuatorTempPort {
            in actuatorTemp : TemperatureValue;
        }
        state def ControllerStates {
            initial state Inactive;
            state Monitoring;
            state ActiveControl;
            state Emergency;
            transition from Inactive to Monitoring when (slipRatio > 0.0);
            transition from Monitoring to ActiveControl when (slipRatio > targetSlipRatio);
            transition from ActiveControl to Monitoring when (slipRatio < targetSlipRatio);
            transition from Inactive to Emergency when (wheelTemp > 120.0);
            transition from Monitoring to Emergency when (wheelTemp > 120.0);
            transition from ActiveControl to Emergency when (wheelTemp > 120.0);
        }
    }
    
    part def TorqueActuator {
        port availableTorquePort {
            in availableTorque : TorqueCommandValue;
        }
        port torqueCommandPort {
            in torqueCommand : TorqueCommandValue;
        }
        port actuatorTempPort {
            out actuatorTemp : TemperatureValue;
        }
        port outputTorquePort {
            out outputTorque : TorqueCommandValue;
        }
        action modulateTorque {
            in availableTorque : TorqueCommandValue;
            in torqueCommand : TorqueCommandValue;
            out outputTorque : TorqueCommandValue;
        }
    }
    
    part def Powertrain {
        port powertrainTempPort {
            out powertrainTemp : TemperatureValue;
        }
        port availableTorquePort {
            out availableTorque : TorqueCommandValue;
        }
    }
    
    part def WheelAssembly {
        port appliedTorquePort {
            in appliedTorque : TorqueCommandValue;
        }
        port wheelTempPort {
            out wheelTemp : TemperatureValue;
        }
        port wheelSpeedPort {
            out wheelSpeed : WheelSpeedValue;
        }
    }
    
    part def Vehicle {
        part velocitySensor : VelocitySensor;
        part slipEstimator : SlipEstimator;
        part tractionController : TractionController;
        part torqueActuator : TorqueActuator;
        part powertrain : Powertrain;
        part wheelAssembly : WheelAssembly;
        
        flow wheelSpeedSensedFlow of WheelSpeedValue 
            from wheelAssembly.wheelSpeedPort.wheelSpeed to velocitySensor.measuredWheelSpeedPort.measuredWheelSpeed;
        flow wheelSpeedToEstimatorFlow of WheelSpeedValue 
            from velocitySensor.wheelSpeedPort.wheelSpeed to slipEstimator.wheelSpeedPort.wheelSpeed;
        flow vehicleSpeedFlow of VehicleSpeedValue 
            from velocitySensor.vehicleSpeedPort.vehicleSpeed to slipEstimator.vehicleSpeedPort.vehicleSpeed;
        flow slipRatioFlow of SlipRatioValue 
            from slipEstimator.slipRatioPort.slipRatio to tractionController.slipRatioPort.slipRatio;
        flow availableTorqueFlow of TorqueCommandValue 
            from powertrain.availableTorquePort.availableTorque to torqueActuator.availableTorquePort.availableTorque;
        flow torqueCommandFlow of TorqueCommandValue 
            from tractionController.torqueCommandPort.torqueCommand to torqueActuator.torqueCommandPort.torqueCommand;
        flow torqueDeliveryFlow of TorqueCommandValue 
            from torqueActuator.outputTorquePort.outputTorque to wheelAssembly.appliedTorquePort.appliedTorque;
        flow wheelTempFlow of TemperatureValue 
            from wheelAssembly.wheelTempPort.wheelTemp to tractionController.wheelTempPort.wheelTemp;
        flow powertrainTempFlow of TemperatureValue 
            from powertrain.powertrainTempPort.powertrainTemp to tractionController.powertrainTempPort.powertrainTemp;
        flow actuatorTempFlow of TemperatureValue 
            from torqueActuator.actuatorTempPort.actuatorTemp to tractionController.actuatorTempPort.actuatorTemp;
    }
    
    requirement def TractionControlRequirement {
        subject system : Vehicle;
        requirement SlipPrevention {
            doc /* The system must prevent wheel slip by modulating torque. */
        }
        requirement ThermalSafety {
            doc /* The system must monitor temperatures and enter emergency mode if thresholds are exceeded. */
        }
    }
}
