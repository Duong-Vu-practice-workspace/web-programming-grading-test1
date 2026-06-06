package vn.edu.ptit.d22.web_programming_grading_api.controllers;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TestController {
    @GetMapping("/test")
    public String test() {
        return "Hello";
    }
    @GetMapping("/test2")
    public String test2() {
        return "Hello 2";
    }
    @GetMapping("/test3")
    public String test3() {
        return "Hello 3";
    }
}
