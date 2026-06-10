package com.example.demo.service;

import com.example.demo.model.User;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
public class ExternalApiService {
    private final RestTemplate restTemplate;
    
    public ExternalApiService(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }
    
    public User fetchUserFromApi(int id) {
        String url = "https://jsonplaceholder.typicode.com/users/" + id;
        return restTemplate.getForObject(url, User.class);
    }
}
