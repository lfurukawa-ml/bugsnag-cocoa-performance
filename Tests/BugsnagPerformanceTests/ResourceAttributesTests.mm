//
//  ResourceAttributesTests.mm
//  BugsnagPerformance-iOSTests
//
//  Created by Nick Dowell on 02/11/2022.
//  Copyright © 2022 Bugsnag. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "../../Sources/BugsnagPerformance/Private/ResourceAttributes.h"

using namespace bugsnag;

@interface ResourceAttributesTests : XCTestCase

@end

@implementation ResourceAttributesTests

- (void)testDeploymentEnvironment {
    auto attributes = ResourceAttributes([BugsnagPerformanceConfiguration loadConfig]).get();
    XCTAssertEqualObjects(attributes[@"deployment.environment"], @"development");
}

- (void)testDeploymentEnvironmentFromReleaseStage {
    auto config = [BugsnagPerformanceConfiguration loadConfig];
    config.releaseStage = @"staging";
    auto attributes = ResourceAttributes(config).get();
    XCTAssertEqualObjects(attributes[@"deployment.environment"], @"staging");
}

- (void)testDeviceModelIdentifier {
    auto attributes = ResourceAttributes([BugsnagPerformanceConfiguration loadConfig]).get();
    auto modelId = (NSString *)attributes[@"device.model.identifier"];
    XCTAssertGreaterThan(modelId.length, 0);
    XCTAssertTrue([modelId containsString:@","]);
    XCTAssertFalse([modelId containsString:@"\0"]);
}

@end