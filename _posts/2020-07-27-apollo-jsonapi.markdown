---
layout: post
title:  "Using GraphQL with JSON APIs"
date:   2020-07-27
categories: graphql jsonapi json javascript apollo
---


I've had the pleasure to work with GraphQL in some of our more recently built
applications at work. Developing frontend applications backend by a GraphQL API
is the most productive my team and I have ever been--the flexibility provided
lets you try out a variety of UX solutions to your problem, without any
additional work to restructure your backend.

In some of our older applications, we have APIs that range from
do-everything-at-once tangled webs to decently well-structured [JSON API spec](https://jsonapi.org/)
compliant RESTful APIs. When we decided to expirement with new workflows built on top of
one of these existing applications, we were torn between two choices:

1. Get the benefits of GraphQL, but have to reimplement all the convoluted
     business logic already baked into a JSON API.
2. Use the existing JSON API, but be stuck with managing resources on the
     client using something like Redux.

As a way to jump straight to interating on the UI, I made a translation layer
from the JSON API to GraphQL with Apollo, all of which takes place on the client,
with no changes needed on the server: [Apollo Link JSON API](https://github.com/Rsullivan00/apollo-link-json-api).


### Queries

[`apollo-link-json-api`](https://github.com/Rsullivan00/apollo-link-json-api) lets you
write GraphQL that actually talks to a JSON API service.


```graphql
query firstAuthor {
  author @jsonapi(path: "authors/1") {
    name
  }
}
```

It will traverse relationships in related resources, and unpack them to a
structure that Apollo can use as if it were GraphQL.

```graphql
query firstAuthor {
  author @jsonapi(path: "authors/1?include=series,series.books") {
    name
    series {
      title
      books {
        title
      }
    }
  }
}
```

You can try out a demo GraphQL explorer [here](https://optimistic-wozniak-806209.netlify.app/).
Or check out the source [here](https://github.com/Rsullivan00/apollo-link-json-api).


### Mutations

Mutations are not quite as magic as querying--you have to interface
with the JSON API structure for data inputs, though the translation on the
response happens as usual.


```jsx
import React from 'react'
import gql from 'graphql-tag'
import { Mutation } from 'react-apollo'

export const UPDATE_BOOK_TITLE = gql`
  mutation UpdateBookTitle($input: UpdateBookTitleInput!) {
    book(input: $input) @jsonapi(path: "/books/{args.input.data.id}", method: "PATCH") {
      title
    }
  }
`

const UpdateBookTitleButton = ({ bookId }) => (
  <Mutation
    mutation={UPDATE_BOOK_TITLE}
    update={(store, { data: { book } }) => {
      // Update your Apollo cache with result
      console.log(book.title)
    }}
  >
    {mutate => (
      <button onClick={() =>
        mutate({
          variables: {
            input: { // This part needs to be JSON API
              data: {
                id: bookId,
                type: 'books',
                attributes: { title: 'Changed title!' }
              }
            }
          },
          optimisticResponse: {
            book: {
              __typename: 'books',
              title: 'Changed title!'
            }
          }
        })
        }>
        Update your book title!
        </button>
    )}
  </Mutation>
)
```


### The Bad


Apollo Link JSON API currently [doesn't handle HTTP error statuses very well](https://github.com/Rsullivan00/apollo-link-json-api/issues/26)--
Apollo considers anything that's not 2XX to be a Network Error, which means that
useful HTTP statuses like `422` and their error messages are not easily
available in the query result.


This is totally fixable, but I haven't found a great solution yet. PRs are
welcome if you have a way to improve that behavior!
