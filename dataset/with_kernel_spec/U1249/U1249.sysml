package 'User Interface System' {
    private import ScalarValues::*;
    private import SI::*;

    item def UserInput;
    item def ValidatedCommand;
    item def DisplayContent;
    item def Feedback;
    item def ErrorSignal;
    item def ResetCommand;

    port def InputPort {
        in item input : UserInput;
    }
    port def CommandOutPort {
        out item command : ValidatedCommand;
    }
    port def CommandInPort {
        in item command : ValidatedCommand;
    }
    port def ContentOutPort {
        out item content : DisplayContent;
    }
    port def ContentInPort {
        in item content : DisplayContent;
    }
    port def FeedbackOutPort {
        out item feedback : Feedback;
    }
    port def FeedbackInPort {
        in item feedback : Feedback;
    }

    part def InputProcessor {
        port inputPort : InputPort;
        port commandOut : CommandOutPort;
        attribute accuracy : Real = 98.5;
        attribute maxProcessingTime : Real = 50.0;

        state processing {
            entry; then waiting;
            state waiting;
            accept input : UserInput via inputPort
                then validating;
            state validating;
            transition validating_to_waiting
                first validating
                do send new ValidatedCommand() via commandOut
                then waiting;
        }
    }

    part def ApplicationCore {
        port commandIn : CommandInPort;
        port contentOut : ContentOutPort;
        attribute sessionActive : Boolean = false;

        state coreBehavior {
            entry; then idle;
            state idle;
            accept command : ValidatedCommand via commandIn
                then processing;
            state processing;
            transition processing_to_idle
                first processing
                do send new DisplayContent() via contentOut
                then idle;
        }
    }

    part def DisplayManager {
        port contentIn : ContentInPort;
        port feedbackOut : FeedbackOutPort;
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute refreshRate : Real = 60.0;

        state displayBehavior {
            entry; then ready;
            state ready;
            accept content : DisplayContent via contentIn
                then rendering;
            state rendering;
            transition rendering_to_ready
                first rendering
                do send new Feedback() via feedbackOut
                then ready;
        }
    }

    part def InterfaceController {
        port commandIn : CommandInPort;
        port contentIn : ContentInPort;
        port feedbackIn : FeedbackInPort;
        attribute maxResponseTime : Real = 200.0;

        state interfaceStates {
            entry; then idle;
            state idle;
            accept command : ValidatedCommand via commandIn
                then active;
            state active;
            accept feedback : Feedback via feedbackIn
                then idle;
            accept errSignal : ErrorSignal
                then error;
            state error;
            accept resetSignal : ResetCommand
                then idle;
        }
    }

    requirement def AccuracyRequirement {
        doc /* The input processor shall achieve an accuracy greater than 98 percent. */
        attribute minAccuracy : Real = 98.0;
    }
    requirement def ProcessingTimeRequirement {
        doc /* The input processor shall process input within 50 milliseconds. */
        attribute maxTime : Real = 50.0;
    }
    requirement def DisplayResolutionRequirement {
        doc /* The display shall have a resolution of 1920x1080 pixels. */
        attribute reqWidth : Integer = 1920;
        attribute reqHeight : Integer = 1080;
    }
    requirement def RefreshRateRequirement {
        doc /* The display shall have a refresh rate of 60 Hz. */
        attribute minRefreshRate : Real = 60.0;
    }
    requirement def ResponseTimeRequirement {
        doc /* The overall response time shall be less than 200 milliseconds. */
        attribute maxResponse : Real = 200.0;
    }

    part uiSystem {
        port userInputPort : InputPort;
        port systemFeedbackPort : FeedbackOutPort;
        
        part inputProcessor : InputProcessor;
        part appCore : ApplicationCore;
        part displayManager : DisplayManager;
        part controller : InterfaceController;

        connect userInputPort to inputProcessor.inputPort;
        connect inputProcessor.commandOut to appCore.commandIn;
        connect inputProcessor.commandOut to controller.commandIn;
        connect appCore.contentOut to displayManager.contentIn;
        connect appCore.contentOut to controller.contentIn;
        connect displayManager.feedbackOut to controller.feedbackIn;
        connect displayManager.feedbackOut to systemFeedbackPort;

        satisfy AccuracyRequirement by inputProcessor;
        satisfy ProcessingTimeRequirement by inputProcessor;
        satisfy DisplayResolutionRequirement by displayManager;
        satisfy RefreshRateRequirement by displayManager;
        satisfy ResponseTimeRequirement by controller;
    }
}
